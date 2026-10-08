import Foundation
import UIKit
import NitroModules
import UserComSDK
import UserNotifications

private final class UserComFallbackFontResolver: NSObject, FontResolving {
    func resolveFontFor(name: String, size: CGFloat) -> UIFont? {
        UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
    }
}

class HybridUserComModule: HybridUserComModuleSpec, InAppNotificationClickDelegate {
    private let pushApi = UserComPushApi()
    private let messagingLock = NSLock()
    private var registrationGeneration: UInt64 = 0
    private var pushEnabled = false
    private var inAppEnabled = false
    private var linkHandler: ((String) -> Void)?
    private var pendingInAppLink: String?
    private var activeInAppOwner: String?
    private let fontResolver = UserComFallbackFontResolver()

    private func withMessagingState<T>(_ action: () -> T) -> T {
        messagingLock.lock()
        defer { messagingLock.unlock() }
        return action()
    }

    func setMessagingEnabled(pushEnabled: Bool, inAppEnabled: Bool) throws {
        withMessagingState {
            let wasEnabled = self.pushEnabled || self.inAppEnabled
            self.pushEnabled = pushEnabled
            self.inAppEnabled = inAppEnabled
            if !inAppEnabled { pendingInAppLink = nil; activeInAppOwner = nil }
            UserDefaults.standard.set(pushEnabled, forKey: "nitro.usercom.push-enabled")
            if wasEnabled && !pushEnabled && !inAppEnabled { pushApi.invalidatePendingBindings() }
        }
        if pushEnabled {
            DispatchQueue.main.async {
                if self.withMessagingState({ self.pushEnabled }) { UserComPresentationDelegate.install() }
            }
        }
        if !pushEnabled {
            let center = UNUserNotificationCenter.current()
            center.getPendingNotificationRequests { requests in
                guard !self.withMessagingState({ self.pushEnabled }) else { return }
                center.removePendingNotificationRequests(withIdentifiers: requests.filter {
                    $0.identifier.hasPrefix("usercom-")
                }.map { $0.identifier })
            }
            center.getDeliveredNotifications { notifications in
                guard !self.withMessagingState({ self.pushEnabled }) else { return }
                center.removeDeliveredNotifications(withIdentifiers: notifications.filter {
                    $0.request.identifier.hasPrefix("usercom-")
                }.map { $0.request.identifier })
            }
        }
    }

    func setNotificationLinkHandler(handler: ((String) -> Void)?) throws {
        let pending: String? = withMessagingState {
            linkHandler = handler
            guard handler != nil, inAppEnabled else { return nil }
            let pending = pendingInAppLink
            pendingInAppLink = nil
            return pending
        }
        if let handler, let pending { handler(pending) }
    }

    func inAppNotificationDidClick(url: URL) -> Bool {
        let handler: ((String) -> Void)? = withMessagingState {
            guard inAppEnabled, activeInAppOwner == pushApi.userId else { return nil }
            if linkHandler == nil { pendingInAppLink = url.absoluteString }
            return linkHandler
        }
        handler?(url.absoluteString)
        return true
    }

    func consumeInitialNotification() throws -> AnyMap? { return nil }

    func registerPushToken(token: String) throws -> Promise<Void> {
        guard withMessagingState({ pushEnabled || inAppEnabled }) else {
            return Promise.rejected(withError: NSError(domain: "Messaging is disabled", code: 1))
        }
        let promise = Promise<Void>()
        pushApi.bind(token) { error in
            if let error { promise.reject(withError: error) } else { promise.resolve() }
        }
        return promise
    }

    func unregisterPushToken() throws -> Promise<Void> {
        let promise = Promise<Void>()
        pushApi.unbind { error in
            if let error { promise.reject(withError: error) } else { promise.resolve() }
        }
        return promise
    }

    func handleNotification(data: AnyMap, foreground: Bool, opened: Bool) throws -> Promise<Bool> {
        let payload = data.toDictionary().compactMapValues { $0 }
        guard payload.values.contains(where: { ($0 as? String) == "user_com_notification" }) else {
            return Promise.resolved(withResult: false)
        }
        let inApp = String(describing: payload["type"] ?? "") == "4" || payload["inapp_message"] != nil
        if let owner = payload["_nitro_user_id"] as? String, owner != pushApi.userId {
            return Promise.resolved(withResult: false)
        }
        let owner = pushApi.userId
        guard withMessagingState({ inApp ? (inAppEnabled && foreground && !opened) : pushEnabled }) else {
            return Promise.resolved(withResult: false)
        }
        let promise = Promise<Bool>()
        if opened {
            guard let id = payload["id"] as? String else {
                return Promise.rejected(withError: NSError(domain: "Missing notification delivery ID", code: 1))
            }
            pushApi.clicked(id) { error in
                if let error { promise.reject(withError: error) } else { promise.resolve(withResult: true) }
            }
        } else if inApp {
            DispatchQueue.main.async {
                let allowed = self.withMessagingState {
                    guard self.inAppEnabled, self.pushApi.userId == owner else { return false }
                    self.activeInAppOwner = owner
                    return true
                }
                guard allowed, let sdk = UserSDK.default else { promise.resolve(withResult: false); return }
                sdk.inAppNotificationClickDelegate = self
                sdk.handleNotification(userInfo: payload)
                promise.resolve(withResult: true)
            }
        } else {
            // Data-only User.com pushes need local display. Alert payloads are displayed
            // by APNs/RNFB; the host must not forward those a second time in background.
            let content = UNMutableNotificationContent()
            content.title = payload["title"] as? String ?? ""
            content.body = payload["message"] as? String ?? ""
            content.sound = .default
            let id = payload["id"] as? String ?? UUID().uuidString
            var userInfo = payload
            userInfo["_nitro_user_id"] = owner
            // Retain the original FCM message ID so RNFB forwards local taps too.
            userInfo["gcm.message_id"] = payload["gcm.message_id"] ?? id
            userInfo["_nitro_local"] = "1"
            content.userInfo = userInfo
            DispatchQueue.main.async {
                guard self.withMessagingState({ self.pushEnabled && self.pushApi.userId == owner }) else {
                    promise.resolve(withResult: false); return
                }
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "usercom-\(id)", content: content, trigger: nil)) { error in
                    if let error { promise.reject(withError: error) } else { promise.resolve(withResult: true) }
                }
            }
        }
        return promise
    }
    
    func initialize(config: UserComModuleConfig) throws -> NitroModules.Promise<Void> {
        try pushApi.configure(config)
        NSLog("[UserCom] HybridUserCom native initializing")
        
        let domain = config.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = domain.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let promise = Promise<Void>()
        let stateLock = NSLock()
        var settled = false
        let settle: (Error?) -> Void = { error in
            stateLock.lock()
            guard !settled else {
                stateLock.unlock()
                return
            }
            settled = true
            stateLock.unlock()

            if let error = error {
                promise.reject(withError: error)
            } else {
                promise.resolve()
            }
        }
        let timeoutSeconds = max(0, (config.initTimeoutMs ?? 10000) / 1000)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
            settle(NSError(domain: "User.com initialization timed out", code: 1))
        }
        DispatchQueue.main.async {
            let sdk: UserSDK
            if let existing = UserSDK.default, existing.apiKey == config.apiKey, existing.baseURL == host {
                sdk = existing
            } else {
                sdk = UserSDK(application: UIApplication.shared, apiKey: config.apiKey,
                              baseURL: host, shouldTrackActivities: config.trackAllActivities ?? false)
            }
            sdk.fontResolver = self.fontResolver
            sdk.ping { success, error in
                if let error = error {
                    settle(error)
                } else if !success {
                    settle(NSError(domain: "User.com ping failed", code: 1))
                } else {
                    settle(nil)
                }
            }
        }
        return promise
    }
    
    func registerUser(userData: UserComModuleUserData) throws -> NitroModules.Promise<UserComModuleRegisterUserResponse> {
        let promise = Promise<UserComModuleRegisterUserResponse>()
        let requestGeneration = withMessagingState {
            registrationGeneration &+= 1
            return registrationGeneration
        }
        let isCurrent = { self.withMessagingState { self.registrationGeneration == requestGeneration } }
        DispatchQueue.main.async {
            guard isCurrent() else {
                promise.reject(withError: NSError(domain: "User.com registration superseded", code: 1))
                return
            }
            guard let sdk = UserSDK.default else {
                promise.reject(withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0))
                return
            }
            let identified = {
                DispatchQueue.main.async {
                    let current = self.withMessagingState {
                        guard self.registrationGeneration == requestGeneration else { return false }
                        self.pushApi.identify(id: userData.id, key: sdk.userId ?? "")
                        return true
                    }
                    if current { promise.resolve(withResult: UserComModuleRegisterUserResponse.first(NullType.null)) }
                    else { promise.reject(withError: NSError(domain: "User.com registration superseded", code: 1)) }
                }
            }
            var standardData: [UserSDK.UserDataKey: String?] = [.userId: userData.id]
            if let firstName = userData.firstName { standardData[.firstName] = firstName }
            if let lastName = userData.lastName { standardData[.lastName] = lastName }
            if let email = userData.email { standardData[.email] = email }
            if let phoneNumber = userData.phoneNumber { standardData[.phone] = phoneNumber }
            sdk.setUserData(standardData) { success, error in
                if let error { promise.reject(withError: error); return }
                guard success else {
                    promise.reject(withError: NSError(domain: "User.com identify failed", code: 1))
                    return
                }
                guard let attributes = userData.attributes, !attributes.isEmpty else { identified(); return }
                DispatchQueue.main.async {
                    guard isCurrent() else {
                        promise.reject(withError: NSError(domain: "User.com registration superseded", code: 1))
                        return
                    }
                    sdk.setCustomUserData(attributes.mapValues { $0 }) { success, error in
                        if let error { promise.reject(withError: error) }
                        else if !success { promise.reject(withError: NSError(domain: "User.com attributes update failed", code: 1)) }
                        else { identified() }
                    }
                }
            }
        }
        return promise
    }

    func logout() throws -> NitroModules.Promise<Void> {
        let promise = Promise<Void>()
        try setMessagingEnabled(pushEnabled: false, inAppEnabled: false)
        let requestGeneration = withMessagingState {
            registrationGeneration &+= 1
            linkHandler = nil
            pendingInAppLink = nil
            activeInAppOwner = nil
            pushApi.clearIdentity()
            return registrationGeneration
        }
        pushApi.unbind { removalError in
            DispatchQueue.main.async {
                guard self.withMessagingState({ self.registrationGeneration == requestGeneration }) else {
                    promise.reject(withError: NSError(domain: "User.com contact changed during logout", code: 1))
                    return
                }
                guard let sdk = UserSDK.default else {
                    promise.reject(withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0))
                    return
                }
                sdk.logout(fcmToken: nil) { success, error in
                    if let error = error ?? removalError { promise.reject(withError: error) }
                    else if !success { promise.reject(withError: NSError(domain: "User.com logout failed", code: 1)) }
                    else { promise.resolve() }
                }
            }
        }
        return promise
    }

    private func mapToProductEventType(_ eventType: UserComProductEventType) -> UserSDK.EventType {
        switch eventType {
            case .addtocart: return .addToCart
            case .purchase: return .purchase
            case .liking: return .liking
            case .addtoobservation: return .addToObservation
            case .order: return .order
            case .reservation: return .reservation
            case .return: return .return
            case .view: return .view
            case .click: return .click
            case .detail: return .detail
            case .add: return .add
            case .remove: return .remove
            case .checkout: return .checkout
            case .checkoutoption: return .checkoutOption
            case .refund: return .refund
            case .promoclick: return .promoClick
        }
    }

    func sendProductEvent(productId: String, eventType: UserComProductEventType, params: NitroModules.AnyMap?) throws -> NitroModules.Promise<Void> {

        guard let sdk: UserSDK = UserSDK.default else {
            return Promise.rejected(
                withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0)
            )
        }

        let promise = Promise<Void>()
        
        let sdkEventType = mapToProductEventType(eventType)
        sdk.sendProductEvent(productId, eventType: sdkEventType, params: params?.toDictionary().compactMapValues{ $0 }) { success, error in
            if let error = error {
                promise.reject(withError: error)
            } else if !success {
                promise.reject(withError: NSError(domain: "User.com product event failed", code: 1))
            } else {
                promise.resolve()
            }
        }

        return promise
    }
    
    func sendCustomEvent(eventName: String, data: NitroModules.AnyMap) throws -> NitroModules.Promise<Void> {
        
        guard let sdk: UserSDK = UserSDK.default else {
            return Promise.rejected(
                withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0)
            )
        }
        
        let promise = Promise<Void>()
        sdk.sendEvent(with: eventName, params: data.toDictionary().compactMapValues{ $0 }) { success, error in
            if let error = error {
                promise.reject(withError: error)
            } else if !success {
                promise.reject(withError: NSError(domain: "User.com custom event failed", code: 1))
            } else {
                promise.resolve()
            }
        }
        
        return promise
    }
    
    func sendScreenEvent(screenName: String) throws -> NitroModules.Promise<Void> {
        guard let sdk: UserSDK = UserSDK.default else {
            return Promise.rejected(
                withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0)
            )
        }
        
        let promise = Promise<Void>()
        sdk.trackScreen(with: screenName) { success, error in
            if let error = error {
                promise.reject(withError: error)
                return
            }
            if success {
                promise.resolve()
            } else {
                promise.reject(withError: NSError(domain: "User.com screen event failed", code: 1))
            }
        }
        
        return promise
    }
}
