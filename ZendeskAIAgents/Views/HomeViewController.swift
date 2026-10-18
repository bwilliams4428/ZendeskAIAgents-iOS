//
//  HomeViewController.swift
//  ZendeskAIAgents
//
//  Post-credentials landing screen. Shows the current Zendesk connection
//  status, the auth mode, and a button to start the AI Agents conversation.
//  Also exposes Settings (re-edit credentials, clear, switch auth mode).
//

import UIKit
import ZendeskSDKMessaging
import ZendeskSDK

final class HomeViewController: UIViewController {

    private let stack = UIStackView()
    private let statusLabel = UILabel()
    private let subdomainLabel = UILabel()
    private let authModeLabel = UILabel()
    private let startChatButton = UIButton(type: .system)
    private let visitorInfoButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Zendesk AI Agents"
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )

        setupUI()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    private func setupUI() {
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let header = UILabel()
        header.text = "AI Agents Chat"
        header.font = .systemFont(ofSize: 28, weight: .bold)
        header.textAlignment = .center

        let desc = UILabel()
        desc.text = "Talk to your Zendesk AI Agents bot. Tap Start Chat to begin."
        desc.font = .preferredFont(forTextStyle: .body)
        desc.textColor = .secondaryLabel
        desc.numberOfLines = 0
        desc.textAlignment = .center

        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        subdomainLabel.font = .preferredFont(forTextStyle: .subheadline)
        subdomainLabel.textColor = .secondaryLabel
        subdomainLabel.textAlignment = .center

        authModeLabel.font = .preferredFont(forTextStyle: .subheadline)
        authModeLabel.textColor = .secondaryLabel
        authModeLabel.textAlignment = .center

        var startCfg = UIButton.Configuration.filled()
        startCfg.title = "Start Chat"
        startCfg.image = UIImage(systemName: "bubble.left.and.bubble.right.fill")
        startCfg.imagePadding = 8
        startCfg.cornerStyle = .large
        startCfg.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        startChatButton.configuration = startCfg
        startChatButton.addTarget(self, action: #selector(startChatTapped), for: .touchUpInside)

        var visitorCfg = UIButton.Configuration.tinted()
        visitorCfg.title = "Login as Visitor (JWT)"
        visitorCfg.image = UIImage(systemName: "person.crop.circle")
        visitorCfg.imagePadding = 8
        visitorCfg.cornerStyle = .large
        visitorInfoButton.configuration = visitorCfg
        visitorInfoButton.addTarget(self, action: #selector(visitorInfoTapped), for: .touchUpInside)
        visitorInfoButton.isHidden = true

        var settingsCfg = UIButton.Configuration.plain()
        settingsCfg.title = "Edit Connection"
        settingsCfg.image = UIImage(systemName: "gear")
        settingsCfg.imagePadding = 8
        settingsButton.configuration = settingsCfg
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        var logoutCfg = UIButton.Configuration.plain()
        logoutCfg.title = "Logout Visitor"
        logoutCfg.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
        logoutCfg.imagePadding = 8
        logoutButton.configuration = logoutCfg
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        logoutButton.isHidden = true

        [header, desc, statusLabel, subdomainLabel, authModeLabel,
         startChatButton, visitorInfoButton, logoutButton, settingsButton].forEach {
            stack.addArrangedSubview($0)
        }
        stack.setCustomSpacing(28, after: desc)
        stack.setCustomSpacing(36, after: authModeLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }

    private func refresh() {
        guard let creds = (UIApplication.shared.delegate as? AppDelegate)?.credentialsStore.load() else {
            return
        }
        statusLabel.text = "✅ Connected"
        statusLabel.textColor = .systemGreen
        subdomainLabel.text = "Subdomain: \(creds.subdomainHost)"
        authModeLabel.text = "Auth: \(creds.authMode.displayName)"

        switch creds.authMode {
        case .anonymous:
            visitorInfoButton.isHidden = true
            logoutButton.isHidden = true
        case .jwt:
            visitorInfoButton.isHidden = false
            // Show logout only if user is currently logged in (SDK instance available)
            logoutButton.isHidden = ZendeskSDK.Zendesk.instance == nil
        }
    }

    // MARK: - Actions

    @objc private func startChatTapped() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let initializer = appDelegate.zendeskInitializer

        initializer.initializeIfNeeded { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let err):
                    self?.presentError("Initialization failed: \(err.localizedDescription)")
                case .success:
                    self?.presentChatOrPromptForLogin(initializer: initializer)
                }
            }
        }
    }

    private func presentChatOrPromptForLogin(initializer: ZendeskInitializer) {
        guard let creds = (UIApplication.shared.delegate as? AppDelegate)?.credentialsStore.load() else { return }

        if creds.authMode == .jwt && ZendeskSDK.Zendesk.instance != nil {
            // In JWT mode, ask the user to login first (they can also skip)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let skipAction = UIAlertAction(title: "Skip (anonymous)", style: .default) { [weak self] _ in
                self?.presentChat(initializer: initializer)
            }
            let loginAction = UIAlertAction(title: "Login with JWT", style: .default) { [weak self] _ in
                self?.presentJWTLoginThenChat(creds: creds, appDelegate: appDelegate)
            }
            let alert = UIAlertController(
                title: "Visitor Login",
                message: "You're using JWT auth. Login to be recognized, or continue anonymously for this session.",
                preferredStyle: .alert
            )
            alert.addAction(loginAction)
            alert.addAction(skipAction)
            present(alert, animated: true)
        } else {
            presentChat(initializer: initializer)
        }
    }

    private func presentChat(initializer: ZendeskInitializer) {
        guard let messaging = initializer.messaging else {
            return presentError("Messaging instance not available after init.")
        }
        let chatVC = messaging.messagingViewController()
        navigationController?.pushViewController(chatVC, animated: true)
    }

    private func presentJWTLoginThenChat(creds: ZendeskCredentials, appDelegate: AppDelegate) {
        let alert = UIAlertController(
            title: "Visitor Info",
            message: "Enter your details. Your JWT server will mint a token for this Zendesk account.",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = "Name"
            $0.text = creds.lastVisitorName
            $0.autocapitalizationType = .words
        }
        alert.addTextField {
            $0.placeholder = "Email"
            $0.text = creds.lastVisitorEmail
            $0.keyboardType = .emailAddress
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addTextField {
            $0.placeholder = "External ID (e.g. user_12345)"
            $0.text = creds.lastVisitorExternalID
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Login & Chat", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let name = alert?.textFields?[0].text, !name.isEmpty,
                  let email = alert?.textFields?[1].text, !email.isEmpty,
                  let extID = alert?.textFields?[2].text, !extID.isEmpty else {
                return
            }
            var updated = creds
            updated.lastVisitorName = name
            updated.lastVisitorEmail = email
            updated.lastVisitorExternalID = extID
            try? appDelegate.credentialsStore.save(updated)

            self.fetchAndLogin(
                creds: creds,
                visitor: .init(name: name, email: email, externalID: extID),
                appDelegate: appDelegate
            )
        })
        present(alert, animated: true)
    }

    private func fetchAndLogin(
        creds: ZendeskCredentials,
        visitor: JWTAuthService.Visitor,
        appDelegate: AppDelegate
    ) {
        Task {
            do {
                let token = try await appDelegate.authService.fetchToken(credentials: creds, visitor: visitor)
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    appDelegate.zendeskInitializer.loginUser(jwt: token) { result in
                        switch result {
                        case .success: cont.resume()
                        case .failure(let err): cont.resume(throwing: err)
                        }
                    }
                }
                await MainActor.run {
                    self.refresh()
                    self.presentChat(initializer: appDelegate.zendeskInitializer)
                }
            } catch {
                await MainActor.run { self.presentError("Login failed: \(error.localizedDescription)") }
            }
        }
    }

    @objc private func visitorInfoTapped() {
        guard let creds = (UIApplication.shared.delegate as? AppDelegate)?.credentialsStore.load() else { return }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        presentJWTLoginThenChat(creds: creds, appDelegate: appDelegate)
    }

    @objc private func logoutTapped() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.zendeskInitializer.logoutUser { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.presentInfo("Logged out. You can continue as an anonymous visitor.")
                    self?.refresh()
                case .failure(let err):
                    self?.presentError("Logout failed: \(err.localizedDescription)")
                }
            }
        }
    }

    @objc private func settingsTapped() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let vc = CredentialsSetupViewController(credentialsStore: appDelegate.credentialsStore)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentInfo(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
