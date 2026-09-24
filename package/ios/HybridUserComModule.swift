import Foundation
import UIKit
import NitroModules
import UserComSDK

class HybridUserComModule: HybridUserComModuleSpec {
    
    func initialize(config: UserComModuleConfig) throws -> NitroModules.Promise<Void> {
        NSLog("[UserCom] HybridUserCom native initializing")
        
        let domain = config.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = domain.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let sdk = UserSDK(
            application: UIApplication.shared,
            apiKey: config.apiKey,
            baseURL: host,
            shouldTrackActivities: config.trackAllActivities ?? false
        )
        
        let promise = Promise<Void>()
        sdk.ping { success, error in
            if let error = error {
                promise.reject(withError: error)
            } else if !success {
                promise.reject(withError: NSError(domain: "User.com ping failed", code: 1))
            } else {
                promise.resolve()
            }
        }
        return promise
    }
    
    func registerUser(userData: UserComModuleUserData) throws -> NitroModules.Promise<UserComModuleRegisterUserResponse> {
        let promise = Promise<UserComModuleRegisterUserResponse>()
        
        guard let sdk: UserSDK = UserSDK.default else {
            promise.reject(withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0))
            return promise
        }
        
        var standardData: [UserSDK.UserDataKey: String?] = [.userId: userData.id]
        if let firstName = userData.firstName { standardData[.firstName] = firstName }
        if let lastName = userData.lastName { standardData[.lastName] = lastName }
        if let email = userData.email { standardData[.email] = email }
        if let phoneNumber = userData.phoneNumber { standardData[.phone] = phoneNumber }

        sdk.setUserData(standardData) { success, error in
            if let error = error {
                promise.reject(withError: error)
                return
            }
            guard success else {
                promise.reject(withError: NSError(domain: "User.com identify failed", code: 1))
                return
            }

            guard let attributes = userData.attributes, !attributes.isEmpty else {
                promise.resolve(withResult: UserComModuleRegisterUserResponse.first(NullType.null))
                return
            }

            sdk.setCustomUserData(attributes.mapValues { $0 }) { attributesSuccess, attributesError in
                if let attributesError = attributesError {
                    promise.reject(withError: attributesError)
                } else if !attributesSuccess {
                    promise.reject(withError: NSError(domain: "User.com attributes update failed", code: 1))
                } else {
                    promise.resolve(withResult: UserComModuleRegisterUserResponse.first(NullType.null))
                }
            }
        }
        
        return promise
    }
    
    func logout() throws -> NitroModules.Promise<Void> {
        let promise = Promise<Void>()
        
        guard let sdk: UserSDK = UserSDK.default else {
            promise.reject(withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0))
            return promise
        }
        
        sdk.logout(fcmToken: nil) { success, error in
            if let error = error {
                promise.reject(withError: error)
            } else if !success {
                promise.reject(withError: NSError(domain: "User.com logout failed", code: 1))
            } else {
                promise.resolve()
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
