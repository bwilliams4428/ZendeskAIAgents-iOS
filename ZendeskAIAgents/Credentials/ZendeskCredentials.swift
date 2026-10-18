//
//  ZendeskCredentials.swift
//  ZendeskAIAgents
//
//  Credential model. All Zendesk connection details are user-supplied at runtime
//  and persisted to the iOS Keychain — nothing is hardcoded.
//

import Foundation

enum AuthMode: String, CaseIterable, Codable {
    case anonymous
    case jwt

    var displayName: String {
        switch self {
        case .anonymous: return "Anonymous Visitor"
        case .jwt: return "Authenticated (JWT)"
        }
    }
}

struct ZendeskCredentials: Codable, Equatable {
    /// The Messaging channel key from Zendesk Admin Center → Channels → Messaging → SDK
    var channelKey: String

    /// Subdomain only — e.g. "mycompany" for mycompany.zendesk.com
    var subdomain: String

    /// Auth mode
    var authMode: AuthMode

    /// JWT signing secret (only used when authMode == .jwt).
    /// We never store the actual signed token — the server signs on demand.
    var jwtSigningSecret: String?

    /// Base URL of the user's JWT-signing server (only used when authMode == .jwt).
    /// Must return `{ "token": "<jwt>" }` on POST to `${baseURL}/auth/jwt`
    /// and accept either a JSON body with `{ name, email, external_id }`
    /// or a query string.
    var jwtServerBaseURL: String?

    /// Optional override for which visitor fields get sent with the JWT.
    /// Filled in by the user from the home screen when auth is JWT.
    var lastVisitorName: String?
    var lastVisitorEmail: String?
    var lastVisitorExternalID: String?

    var subdomainHost: String { "\(subdomain).zendesk.com" }
}
