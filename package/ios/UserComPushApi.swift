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

    private let storage = UserDefaults.standard
    private let queue = DispatchQueue(label: "com.usercom.token-requests")
    private let bindingKey = "nitro.usercom.token-binding"
    private let removalsKey = "nitro.usercom.token-removals"
    private var host = ""
    private var apiKey = ""
    private var userKey = ""
    private(set) var userId = ""

    func configure(_ config: UserComModuleConfig) throws {
        let value = config.domain.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard value.hasSuffix(".user.com"), !value.contains("/"), !value.contains("@") else {
            throw NSError(domain: "Expected a User.com workspace host", code: 1)
        }
        host = value
        apiKey = config.apiKey
    }

    func identify(id: String, key: String) {
        userId = id; userKey = key
        storage.set(id, forKey: "nitro.usercom.message-owner")
    }

    func bind(_ token: String, completion: @escaping (Error?) -> Void) {
        let binding = Binding(host: host, apiKey: apiKey, userKey: userKey, userId: userId, token: token)
        queue.async {
            do {
                guard !binding.userKey.isEmpty else { throw NSError(domain: "Register a contact first", code: 1) }
                // Store before sending: a timeout does not prove the server ignored the request.
                try self.saveBinding(binding)
                try self.flushRemovals()
                try self.request(binding, method: "POST", path: "api/sdk/v1/ping/", body: [
                    "customer": ["user_id": binding.userId],
                    "device": ["os_type": "iOS", "fcm_key": token]
                ])
                completion(nil)
            } catch { completion(error) }
        }
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
        let binding = Binding(host: host, apiKey: apiKey, userKey: userKey, userId: userId, token: "")
        queue.async {
            do {
                guard id.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
                    throw NSError(domain: "Invalid notification delivery ID", code: 1)
                }
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
        var pending = try removals()
        while let binding = pending.first {
            try request(binding, method: "DELETE", path: "api/sdk/v1/delete-fcm-token/", body: ["fcm_key": binding.token])
            pending.removeFirst()
            storage.set(try JSONEncoder().encode(pending), forKey: removalsKey)
        }
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
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
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
