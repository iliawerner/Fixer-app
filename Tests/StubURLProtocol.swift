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
    nonisolated(unsafe) static var requestedRequests: [URLRequest] = []
    nonisolated(unsafe) static var requestedHTTPBodies: [Data] = []

    static func reset() {
        queue = []
        requestedURLs = []
        requestedRequests = []
        requestedHTTPBodies = []
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
        StubURLProtocol.requestedRequests.append(request)
        if let body = request.httpBody {
            StubURLProtocol.requestedHTTPBodies.append(body)
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            StubURLProtocol.requestedHTTPBodies.append(body)
        }
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
