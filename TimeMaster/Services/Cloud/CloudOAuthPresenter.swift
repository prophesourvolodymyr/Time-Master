import AuthenticationServices
import TimeMasterCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class CloudOAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var webSession: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?
    private var operationID: UUID?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        guard webSession == nil else { throw CloudAuthError.superseded }
        try Task.checkCancellation()
        let id = UUID()
        operationID = id
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    self.operationID = nil
                    continuation.resume(throwing: CloudAuthError.cancelled)
                    return
                }
                self.continuation = continuation
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callback, error in
                    Task { @MainActor in
                        guard let self, self.operationID == id else { return }
                        if let callback { self.finish(.success(callback), id: id) }
                        else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                            self.finish(.failure(CloudAuthError.cancelled), id: id)
                        } else {
                            self.finish(.failure(error ?? CloudAuthError.invalidCallback), id: id)
                        }
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                self.webSession = session
                if !session.start() {
                    self.finish(.failure(CloudAuthError.configuration("The secure sign-in browser could not be presented. Open an app window and try again.")), id: id)
                }
            }
        }, onCancel: {
            Task { @MainActor in self.cancel(id: id) }
        })
    }

    func cancel() {
        if let id = operationID { cancel(id: id) }
    }

    private func cancel(id: UUID) {
        guard operationID == id else { return }
        webSession?.cancel()
        finish(.failure(CloudAuthError.cancelled), id: id)
    }

    private func finish(_ result: Result<URL, Error>, id: UUID) {
        guard operationID == id else { return }
        operationID = nil
        let pending = continuation
        continuation = nil
        webSession = nil
        pending?.resume(with: result)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if os(iOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? ASPresentationAnchor()
#else
        return NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? ASPresentationAnchor()
#endif
    }
}
