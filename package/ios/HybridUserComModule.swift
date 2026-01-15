import Foundation
import NitroModules
import UserSDK

class HybridUserComModule: HybridUserComModuleSpec {
    
    func initialize(config: UserComModuleConfig) throws -> NitroModules.Promise<Void> {
        NSLog("[UserCom] HybridUserCom native initializing")
        
        UserSDK(
            application: UIApplication.shared,
            apiKey: config.apiKey,
            baseURL: config.domain,
            shouldTrackActivities: config.trackAllActivities ?? false
        )
        
        NSLog("[UserCom] HybridUserComModule initialized")
        return Promise.resolved()
    }
    
    func registerUser(userData: UserComModuleUserData) throws -> NitroModules.Promise<UserComModuleRegisterUserResponse> {
        let promise = Promise<UserComModuleRegisterUserResponse>()
        
        guard let sdk: UserSDK = UserSDK.default else {
            promise.reject(withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0))
            return promise
        }
        
        let completionCb: (Bool, Error?) -> Void = { (success: Bool, error: Error?) in
            if let error = error {
                promise.reject(withError: error)
            } else {
                promise.resolve(withResult: UserComModuleRegisterUserResponse.first(NullType.null))
            }
        }
        
        sdk.setUserData([
            UserSDK.UserDataKey.firstName : userData.firstName,
            UserSDK.UserDataKey.lastName : userData.lastName,
            UserSDK.UserDataKey.email : userData.email,
            UserSDK.UserDataKey.userId : userData.id
        ], completionCb)
        
        if let attributes = userData.attributes {
            sdk.setCustomUserData(attributes.mapValues { value in
                return value
            })
        }
        
        return promise
    }
    
    func logout() throws -> NitroModules.Promise<Void> {
        let promise = Promise<Void>()
        
        guard let sdk: UserSDK = UserSDK.default else {
            promise.reject(withError: NSError(domain: "SDK is not initialized, call initialize() first", code: 0))
            return promise
        }
        
        sdk.logout { success, error in
            if let error = error {
                promise.reject(withError: error)
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
            } else {
                promise.resolve()
            }
        }
        
        return promise
    }
}
