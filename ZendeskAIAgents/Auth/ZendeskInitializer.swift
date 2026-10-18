//
//  ZendeskInitializer.swift
//  ZendeskAIAgents
//
//  Single source of truth for the live Zendesk SDK handle. We initialize the
//  SDK once per process with the user's channel key, then either leave them
//  anonymous or call `loginUser(with:)` for authenticated conversations.
//

import Foundation
import ZendeskSDKMessaging
import ZendeskSDK

final class ZendeskInitializer {

    enum InitError: LocalizedError {
        case notConfigured
        case alreadyInitialized
        case sdkFailure(String)
        case noInstance

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "No Zendesk credentials configured."
            case .alreadyInitialized: return "Zendesk SDK is already initialized."
            case .sdkFailure(let msg): return msg
            case .noInstance: return "Zendesk.instance is nil after initialize()."
            }
        }
    }

    private let credentialsStore: CredentialsStore
    private var isInitialized = false
    private let initLock = NSLock()

    init(credentialsStore: CredentialsStore) {
        self.credentialsStore = credentialsStore
    }

    /// Lazily initialize the Zendesk Messaging SDK with the user-configured
    /// channel key. Uses `DefaultMessagingFactory` so we don't need to write
    /// a custom factory. Idempotent.
    func initializeIfNeeded(completion: @escaping (Result<Void, Error>) -> Void) {
        initLock.lock()
        defer { initLock.unlock() }

        if isInitialized {
            completion(.success(()))
            return
        }
        guard let creds = credentialsStore.load() else {
            completion(.failure(InitError.notConfigured))
            return
        }

        ZendeskSDK.Zendesk.initialize(
            withChannelKey: creds.channelKey,
            messagingFactory: ZendeskSDKMessaging.DefaultMessagingFactory()
        ) { result in
            switch result {
            case .success:
                self.isInitialized = true
                completion(.success(()))
            case .failure(let error):
                completion(.failure(InitError.sdkFailure("Zendesk init failed: \(error.localizedDescription)")))
            }
        }
    }

    /// Authenticate the current user with a JWT.
    /// Must call `initializeIfNeeded` first.
    func loginUser(jwt: String, completion: @escaping (Result<Void, Error>) -> Void) {
        initializeIfNeeded { result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success:
                guard let zendesk = ZendeskSDK.Zendesk.instance else {
                    completion(.failure(InitError.noInstance))
                    return
                }
                zendesk.loginUser(with: jwt) { loginResult in
                    switch loginResult {
                    case .success:
                        completion(.success(()))
                    case .failure(let err):
                        completion(.failure(InitError.sdkFailure("JWT login failed: \(err.localizedDescription)")))
                    }
                }
            }
        }
    }

    /// Log the current user out (back to anonymous).
    func logoutUser(completion: @escaping (Result<Void, Error>) -> Void) {
        initializeIfNeeded { result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success:
                guard let zendesk = ZendeskSDK.Zendesk.instance else {
                    completion(.failure(InitError.noInstance))
                    return
                }
                zendesk.logoutUser { logoutResult in
                    switch logoutResult {
                    case .success:
                        completion(.success(()))
                    case .failure(let err):
                        completion(.failure(InitError.sdkFailure("Logout failed: \(err.localizedDescription)")))
                    }
                }
            }
        }
    }

    /// Returns the Zendesk Messaging instance, after initialization.
    /// Use this to get the chat UI view controller.
    var messaging: ZendeskSDK.Messaging? {
        ZendeskSDK.Zendesk.instance?.messaging
    }
}
