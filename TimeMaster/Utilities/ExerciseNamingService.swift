import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Sends a photo to the OpenAI Vision API and returns a suggested exercise name.
enum ExerciseNamingService {

    // MARK: - Public

    #if os(iOS)
    static func suggestName(
        image: UIImage,
        apiKey: String,
        model: String
    ) async throws -> String {
        try await suggestName(jpegData: image.jpegData(compressionQuality: 0.7), apiKey: apiKey, model: model)
    }
    #elseif os(macOS)
    static func suggestName(
        image: NSImage,
        apiKey: String,
        model: String
    ) async throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        else { throw NamingError.imageEncodingFailed }
        return try await suggestName(jpegData: jpegData, apiKey: apiKey, model: model)
    }
    #endif

    private static func suggestName(jpegData: Data, apiKey: String, model: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NamingError.missingAPIKey
        }
        let base64 = jpegData.base64EncodedString()

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 20,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a fitness expert. The user will show you an image of a workout exercise. Reply with ONLY the exercise name — 1 to 4 words, no punctuation, no explanation."
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(base64)", "detail": "low"]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NamingError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let errMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
            throw NamingError.apiError(errMsg ?? "HTTP \(http.statusCode)")
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw NamingError.invalidResponse
        }

        let name = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw NamingError.emptyResponse }
        return name
    }

    // MARK: - Errors

    enum NamingError: LocalizedError {
        case missingAPIKey
        case imageEncodingFailed
        case invalidResponse
        case emptyResponse
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "No API key. Add yours in Settings → Exercise AI."
            case .imageEncodingFailed:
                return "Could not read the image."
            case .invalidResponse:
                return "Unexpected response from OpenAI."
            case .emptyResponse:
                return "OpenAI returned an empty name."
            case .apiError(let msg):
                return "OpenAI error: \(msg)"
            }
        }
    }
}
