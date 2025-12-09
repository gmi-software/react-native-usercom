import Foundation
import NitroModules
import UserSDK

class HybridUserComModule: HybridUserComModuleSpec {
    
    func initialize(config: UserComModuleConfig) throws -> NitroModules.Promise<Void> {        
        NSLog("[UserCom] HybridUserCom native initializing")
        
        let sdk = UserSDK(
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
}
