import Foundation

/// A `URLProtocol` stub for driving `GeminiAPI`'s injected `URLSession` in tests.
/// Queue up `(statusCode, data)` responses; they're returned in order, one per
/// request. Requested URLs are recorded so tests can assert on pagination.
final class StubURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let data: Data
    }

    nonisolated(unsafe) static var queue: [Stub] = []
    nonisolated(unsafe) static var requestedURLs: [URL] = []

    static func reset() {
        queue = []
        requestedURLs = []
    }

    /// A session wired to use this stub protocol instead of the network.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url { StubURLProtocol.requestedURLs.append(url) }
        let stub = StubURLProtocol.queue.isEmpty
            ? Stub(statusCode: 200, data: Data())
            : StubURLProtocol.queue.removeFirst()
        let http = HTTPURLResponse(url: request.url!, statusCode: stub.statusCode,
                                   httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
