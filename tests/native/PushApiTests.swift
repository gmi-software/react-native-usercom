import Foundation

// Stand-in for generated Nitro config; native module integration is built separately.
struct UserComModuleConfig { let domain: String; let apiKey: String }

final class MemoryDefaults: UserDefaults {
    private let lock = NSLock()
    private var values: [String: Any] = [:]
    override func set(_ value: Any?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }; values[key] = value
    }
    override func data(forKey key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }; return values[key] as? Data
    }
    override func string(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }; return values[key] as? String
    }
    override func removeObject(forKey key: String) {
        lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key)
    }
}

final class StubProtocol: URLProtocol {
    struct Call { let method: String; let token: String; let key: String; let userId: String }
    static let lock = NSLock()
    static var calls: [Call] = []
    static var deleteStatus = 200
    static var postStatus = 200
    static var postStarted: DispatchSemaphore?
    static var releasePost: DispatchSemaphore?
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        calls = []; deleteStatus = 200; postStatus = 200
        postStarted = nil; releasePost = nil
    }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.user.com" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var result = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                result.append(contentsOf: buffer.prefix(count))
            }
            body = result
        }
        let json = (try? JSONSerialization.jsonObject(with: body ?? Data())) as? [String: Any] ?? [:]
        let method = request.httpMethod ?? ""
        let device = json["device"] as? [String: Any] ?? [:]
        let customer = json["customer"] as? [String: Any] ?? [:]
        Self.lock.lock()
        Self.calls.append(Call(method: method, token: (json["fcm_key"] ?? device["fcm_key"]) as? String ?? "",
            key: request.value(forHTTPHeaderField: "X-User-Key") ?? "", userId: customer["user_id"] as? String ?? ""))
        let status = method == "DELETE" ? Self.deleteStatus : Self.postStatus
        let started = Self.postStarted; let release = Self.releasePost
        Self.lock.unlock()
        if method == "POST", let started, let release {
            started.signal(); _ = release.wait(timeout: .now() + 10)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func awaitCall(_ operation: (@escaping (Error?) -> Void) -> Void) -> Error? {
    let done = DispatchSemaphore(value: 0)
    var result: Error?
    operation { result = $0; done.signal() }
    precondition(done.wait(timeout: .now() + 20) == .success, "Operation hung")
    return result
}
func makeAPI() throws -> (UserComPushApi, MemoryDefaults) {
    StubProtocol.reset()
    let store = MemoryDefaults(suiteName: UUID().uuidString)!
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubProtocol.self]
    let api = UserComPushApi(storage: store, session: URLSession(configuration: config))
    try api.configure(UserComModuleConfig(domain: "fixture.user.com", apiKey: "fixture-sdk-key"))
    api.identify(id: "account-a", key: "key-a")
    return (api, store)
}
func pendingCount(_ store: MemoryDefaults) -> Int {
    let data = store.data(forKey: "nitro.usercom.token-removals") ?? Data("[]".utf8)
    return (try! JSONSerialization.jsonObject(with: data) as! [Any]).count
}

@main struct PushApiTests {
    static func main() throws {
        var cases = 0
        for code in [404, 410, 401, 429, 503] {
            let (api, store) = try makeAPI()
            precondition(awaitCall { api.bind("old", completion: $0) } == nil)
            StubProtocol.deleteStatus = code
            precondition(awaitCall { api.bind("new", completion: $0) } == nil, "Old removal blocked a new bind")
            let error = awaitCall { api.unbind(completion: $0) }
            if [404, 410].contains(code) {
                precondition(error == nil && pendingCount(store) == 0)
            } else {
                precondition((error as NSError?)?.code == code && pendingCount(store) == 2)
                StubProtocol.deleteStatus = 200
                precondition(awaitCall { api.unbind(completion: $0) } == nil && pendingCount(store) == 0)
            }
            precondition(StubProtocol.calls.filter { $0.method == "POST" }.count == 2)
            cases += 1
        }
        do {
            let (api, _) = try makeAPI()
            precondition(awaitCall { api.bind("shared", completion: $0) } == nil)
            api.identify(id: "account-b", key: "key-b")
            StubProtocol.deleteStatus = 503
            precondition(awaitCall { api.bind("shared", completion: $0) } == nil)
            StubProtocol.deleteStatus = 200
            precondition(awaitCall { api.unbind(completion: $0) } == nil)
            let deletes = StubProtocol.calls.filter { $0.method == "DELETE" }
            precondition(deletes.count == 1 && deletes[0].key == "key-b", "Old cleanup deleted a transferred token")
            cases += 1
        }
        do {
            let (api, store) = try makeAPI()
            precondition(awaitCall { api.bind("old", completion: $0) } == nil)
            api.clearIdentity()
            precondition(api.userId.isEmpty && store.string(forKey: "nitro.usercom.message-owner") == nil)
            precondition(awaitCall { api.bind("new", completion: $0) } != nil)
            precondition(awaitCall { api.unbind(completion: $0) } == nil)
            let deletes = StubProtocol.calls.filter { $0.method == "DELETE" }
            precondition(deletes.last?.key == "key-a", "Logout lost original removal credentials")
            cases += 1
        }
        do {
            let (api, _) = try makeAPI()
            StubProtocol.postStatus = 401
            precondition((awaitCall { api.bind("new", completion: $0) } as NSError?)?.code == 401)
            precondition(awaitCall { api.unbind(completion: $0) } == nil)
            cases += 1
        }
        do {
            let (api, _) = try makeAPI()
            let started = DispatchSemaphore(value: 0); let release = DispatchSemaphore(value: 0)
            StubProtocol.postStarted = started; StubProtocol.releasePost = release
            let done = DispatchSemaphore(value: 0)
            var result: Error?
            api.bind("stale") { result = $0; done.signal() }
            precondition(started.wait(timeout: .now() + 10) == .success)
            api.clearIdentity(); release.signal()
            precondition(done.wait(timeout: .now() + 10) == .success && result != nil)
            StubProtocol.postStarted = nil; StubProtocol.releasePost = nil
            precondition(awaitCall { api.unbind(completion: $0) } == nil && api.userId.isEmpty)
            cases += 1
        }
        do {
            let (api, _) = try makeAPI()
            let group = DispatchGroup()
            DispatchQueue.concurrentPerform(iterations: 200) { i in
                api.identify(id: "account-\(i)", key: "key-\(i)")
                _ = api.userId
                group.enter()
                api.bind("token-\(i)") { _ in group.leave() }
            }
            precondition(group.wait(timeout: .now() + 20) == .success)
            precondition(awaitCall { api.unbind(completion: $0) } == nil)
            for call in StubProtocol.calls where call.method == "POST" {
                precondition(call.userId.replacingOccurrences(of: "account-", with: "") == call.key.replacingOccurrences(of: "key-", with: ""), "Mixed contact snapshot")
            }
            cases += 1
        }
        print("iOS push helper: \(cases) cases passed")
    }
}
