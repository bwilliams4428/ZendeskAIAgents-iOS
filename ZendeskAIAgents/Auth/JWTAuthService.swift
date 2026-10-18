//
//  JWTAuthService.swift
//  ZendeskAIAgents
//
//  Calls a user-configured HTTP endpoint to mint a JWT, then hands it
//  to the Zendesk SDK via `Zendesk.loginUser(jwt:)`.
//

import Foundation

final class JWTAuthService {

    enum AuthError: LocalizedError {
        case noServerConfigured
        case badResponse(Int)
        case noTokenInResponse
        case httpFailure(String)

        var errorDescription: String? {
            switch self {
            case .noServerConfigured: return "No JWT server URL is configured."
            case .badResponse(let code): return "JWT server returned HTTP \(code)."
            case .noTokenInResponse: return "JWT server response did not include a 'token' field."
            case .httpFailure(let msg): return msg
            }
        }
    }

    struct Visitor {
        let name: String
        let email: String
        let externalID: String
    }

    /// Fetches a signed JWT from the user's server.
    /// Expected contract: POST `${baseURL}/auth/jwt` with JSON body
    /// `{ "name": "...", "email": "...", "external_id": "..." }`
    /// and receive `{ "token": "<jwt>" }`.
    func fetchToken(credentials: ZendeskCredentials, visitor: Visitor) async throws -> String {
        guard let baseURLString = credentials.jwtServerBaseURL,
              let baseURL = URL(string: baseURLString) else {
            throw AuthError.noServerConfigured
        }

        let url = baseURL.appendingPathComponent("auth/jwt")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        let body: [String: String] = [
            "name": visitor.name,
            "email": visitor.email,
            "external_id": visitor.externalID
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw AuthError.httpFailure("Network error: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.httpFailure("Non-HTTP response from JWT server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthError.badResponse(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              !token.isEmpty else {
            throw AuthError.noTokenInResponse
        }
        return token
    }
}
