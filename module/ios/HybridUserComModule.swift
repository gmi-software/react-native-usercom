import Foundation
import NitroModules
import UserSDK

class HybridUserComModule: HybridUserComModuleSpec {
    func initialize() throws {
        print("HybridUserCom native initializing")
        let sdk = UserSDK(
        application: UIApplication.shared,
        apiKey: "<api_key>",
        baseURL: "<your_domain>.user.com",
        shouldTrackActivities: true)

        print("HybridUserComModule initialized")
    }
}
