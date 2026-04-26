import Foundation
import UIKit

/// Sends a photo to the OpenAI Vision API and returns a suggested exercise name.
enum ExerciseNamingService {

    // MARK: - Public

    static func suggestName(
        image: UIImage,
        apiKey: String,
        model: String
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NamingError.missingAPIKey
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            throw NamingError.imageEncodingFailed
        }
        let base64 = jpeg.base64EncodedString()

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
            // Parse OpenAI error message if available
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
