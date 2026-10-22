import Foundation

actor PhysiquePolicyTransport {
    private let session: URLSession
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: PhysiqueNoRedirects(), delegateQueue: nil)
    }
    func load() async throws -> PhysiquePolicy {
        guard let base = CloudServices.serviceURL(key: "TMRankedServiceURL", fallback: "TMSyncServiceURL") else {
            throw RankedServiceError.message("The Physique service is not configured for this build. Rules and local pose guidance remain available.")
        }
        var request = URLRequest(url: base.appendingPathComponent("v1/physique/policy"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 65_536 else {
            throw RankedServiceError.message("Physique service information could not be confirmed. No capture is shared and no match is started.")
        }
        return try JSONDecoder().decode(PhysiquePolicy.self, from: data)
    }
}

private final class PhysiqueNoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
