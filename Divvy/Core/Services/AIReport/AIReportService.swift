import Foundation

struct AIReportService {
    private static let baseURL = MassiveService.baseURL
    private static let appToken = "F604F620-65D7-493E-BF22-44C35C2B5E86"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func fetchReport(ticker: String) async throws -> AIReportResponse {
        guard let url = URL(string: "\(Self.baseURL)/ai/report/\(ticker.uppercased())") else {
            throw URLError(.badURL)
        }
        let data = try await fetch(url: url)
        do {
            return try Self.decoder.decode(AIReportResponse.self, from: data)
        } catch {
            throw AIReportError.decodingError
        }
    }

    private func fetch(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.appToken, forHTTPHeaderField: "X-App-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 {
                throw AIReportError.unavailable
            }
            if !(200..<300).contains(http.statusCode) {
                throw AIReportError.httpError(statusCode: http.statusCode)
            }
        }
        return data
    }
}

struct AIReportResponse: Decodable {
    let bullCase: [String]
    let bearCase: [String]
    let generatedAt: String
}

enum AIReportError: Error, LocalizedError {
    case httpError(statusCode: Int)
    case decodingError
    case unavailable

    var errorDescription: String? {
        switch self {
        case .httpError(let code): "AI report API returned HTTP \(code)."
        case .decodingError:       "Failed to decode AI report response."
        case .unavailable:         "AI report is temporarily unavailable."
        }
    }
}
