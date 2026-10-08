import Foundation

/// Uses the documented Mobile SDK API, without a privileged REST token or Firebase dependency.
final class UserComPushApi {
    private struct Binding: Codable {
        let host: String
        let apiKey: String
        let userKey: String
        let userId: String
        let token: String
    }

    private let storage: UserDefaults
    private let session: URLSession
    private let stateLock = NSLock()
    private let queue = DispatchQueue(label: "com.usercom.token-requests")
    private let bindingKey = "nitro.usercom.token-binding"
    private let removalsKey = "nitro.usercom.token-removals"
    private var host = ""
    private var apiKey = ""
    private var userKey = ""
    private var currentUserId = ""
    private var generation: UInt64 = 0

    var userId: String { withState { currentUserId } }

    init(storage: UserDefaults = .standard, session: URLSession = .shared) {
        self.storage = storage
        self.session = session
    }

    private func withState<T>(_ action: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return action()
    }

    private func snapshot(_ token: String) -> (Binding, UInt64) {
        withState {
            (Binding(host: host, apiKey: apiKey, userKey: userKey,
                     userId: currentUserId, token: token), generation)
        }
    }

    private func checkIdentity(_ expected: UInt64) throws {
        guard withState({ generation == expected && !userKey.isEmpty }) else {
            throw NSError(domain: "User.com contact changed before token operation", code: 1)
        }
    }

    func invalidatePendingBindings() {
        withState { generation &+= 1 }
    }

    func clearIdentity() {
        withState {
            generation &+= 1
            currentUserId = ""
            userKey = ""
            storage.removeObject(forKey: "nitro.usercom.message-owner")
        }
    }

    func configure(_ config: UserComModuleConfig) throws {
        let value = config.domain.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard value.hasSuffix(".user.com"), !value.contains("/"), !value.contains("@") else {
            throw NSError(domain: "Expected a User.com workspace host", code: 1)
        }
        withState {
            if host != value || apiKey != config.apiKey {
                generation &+= 1
                currentUserId = ""
                userKey = ""
                storage.removeObject(forKey: "nitro.usercom.message-owner")
            }
            host = value
            apiKey = config.apiKey
        }
    }

    func identify(id: String, key: String) {
        withState {
            if currentUserId != id || userKey != key { generation &+= 1 }
            currentUserId = id
            userKey = key
            storage.set(id, forKey: "nitro.usercom.message-owner")
        }
    }

    func bind(_ token: String, completion: @escaping (Error?) -> Void) {
        let (binding, expectedGeneration) = snapshot(token)
        queue.async {
            do {
                try self.checkIdentity(expectedGeneration)
                // Store before sending: a timeout does not prove the server ignored the request.
                try self.saveBinding(binding)
                try self.checkIdentity(expectedGeneration)
                try self.request(binding, method: "POST", path: "api/sdk/v1/ping/", body: [
                    "customer": ["user_id": binding.userId],
                    "device": ["os_type": "iOS", "fcm_key": token]
                ])
                // Successful ping transfers this token to the current contact. Do
                // not let an older removal later delete the newly active token.
                try self.discardTransferredRemovals(binding)
                try self.checkIdentity(expectedGeneration)
                completion(nil)
                // Cleanup errors remain persisted, but do not reject a successful bind.
                do { try self.flushRemovals() }
                catch { NSLog("[UserCom] Previous token removal remains pending: %@", String(describing: error)) }
            } catch { completion(error) }
        }
    }

    private func discardTransferredRemovals(_ active: Binding) throws {
        let pending = try removals().filter { $0.host != active.host || $0.token != active.token }
        storage.set(try JSONEncoder().encode(pending), forKey: removalsKey)
    }

    private func saveBinding(_ binding: Binding) throws {
        if let data = storage.data(forKey: bindingKey) {
            let old = try JSONDecoder().decode(Binding.self, from: data)
            if old.host != binding.host || old.userKey != binding.userKey || old.token != binding.token {
                var pending = try removals()
                if !pending.contains(where: { $0.host == old.host && $0.userKey == old.userKey && $0.token == old.token }) {
                    pending.append(old)
                }
                storage.set(try JSONEncoder().encode(pending), forKey: removalsKey)
            }
        }
        storage.set(try JSONEncoder().encode(binding), forKey: bindingKey)
    }

    func unbind(completion: @escaping (Error?) -> Void) {
        queue.async {
            do {
                if let data = self.storage.data(forKey: self.bindingKey) {
                    let binding = try JSONDecoder().decode(Binding.self, from: data)
                    var pending = try self.removals()
                    if !pending.contains(where: { $0.token == binding.token && $0.userKey == binding.userKey && $0.host == binding.host }) {
                        pending.append(binding)
                    }
                    self.storage.set(try JSONEncoder().encode(pending), forKey: self.removalsKey)
                    self.storage.removeObject(forKey: self.bindingKey)
                }
                try self.flushRemovals()
                completion(nil)
            } catch { completion(error) }
        }
    }

    func clicked(_ id: String, completion: @escaping (Error?) -> Void) {
        let (binding, expectedGeneration) = snapshot("")
        queue.async {
            do {
                guard id.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
                    throw NSError(domain: "Invalid notification delivery ID", code: 1)
                }
                try self.checkIdentity(expectedGeneration)
                try self.request(binding, method: "POST", path: "api/sdk/v1/push-notification/\(id)/clicked/", body: [:])
                completion(nil)
            } catch { completion(error) }
        }
    }

    private func removals() throws -> [Binding] {
        guard let data = storage.data(forKey: removalsKey) else { return [] }
        return try JSONDecoder().decode([Binding].self, from: data)
    }

    private func flushRemovals() throws {
        var retained: [Binding] = []
        var firstError: Error?
        for binding in try removals() {
            do {
                try request(binding, method: "DELETE", path: "api/sdk/v1/delete-fcm-token/", body: ["fcm_key": binding.token])
            } catch {
                let failure = error as NSError
                // An absent/gone token is already detached. Authentication,
                // rate limiting and network errors still need attention/retry.
                if failure.domain == "User.com messaging HTTP" && [404, 410].contains(failure.code) { continue }
                retained.append(binding)
                if firstError == nil { firstError = error }
            }
        }
        storage.set(try JSONEncoder().encode(retained), forKey: removalsKey)
        if let firstError { throw firstError }
    }

    private func request(_ binding: Binding, method: String, path: String, body: [String: Any]) throws {
        guard let url = URL(string: "https://\(binding.host)/\(path)") else {
            throw NSError(domain: "Invalid User.com URL", code: 1)
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = method
        request.setValue("Token \(binding.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(binding.userKey, forHTTPHeaderField: "X-User-Key")
        request.setValue("*/*;version=2", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        // Only the dedicated worker queue waits; UIKit and the JS thread never block.
        let semaphore = DispatchSemaphore(value: 0)
        var resultError: Error?
        let task = session.dataTask(with: request) { _, response, error in
            if let error { resultError = error }
            else if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                resultError = NSError(domain: "User.com messaging HTTP", code: response.statusCode)
            } else if response == nil { resultError = NSError(domain: "Missing User.com response", code: 1) }
            semaphore.signal()
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + 15) == .success else {
            task.cancel()
            throw NSError(domain: "User.com messaging request timed out", code: 1)
        }
        if let resultError { throw resultError }
    }
}
