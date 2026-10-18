//
//  CredentialsSetupViewController.swift
//  ZendeskAIAgents
//
//  The first screen the user sees. They enter their Zendesk account details
//  (channel key, subdomain, JWT details if using authenticated visitors).
//  On save, we persist to Keychain and the app initializes Zendesk.
//

import UIKit

final class CredentialsSetupViewController: UIViewController, UITextFieldDelegate {

    private let credentialsStore: CredentialsStore

    // Form fields
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let channelKeyField = makeField(placeholder: "Messaging Channel Key", secure: false)
    private let subdomainField = makeField(placeholder: "Subdomain (e.g. mycompany)", secure: false)
    private let authModeControl = UISegmentedControl(items: AuthMode.allCases.map { $0.displayName })

    // JWT-specific fields (hidden when authMode == .anonymous)
    private let jwtSecretField = makeField(placeholder: "JWT Signing Secret", secure: true)
    private let jwtServerField = makeField(placeholder: "JWT Server URL (e.g. https://my-jwt-server.com)", secure: false)

    private let saveButton = UIButton(type: .system)
    private let helpLabel = UILabel()
    private let errorLabel = UILabel()

    init(credentialsStore: CredentialsStore) {
        self.credentialsStore = credentialsStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Connect Zendesk"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        setupUI()
        prefillIfEditing()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // Header
        let header = UILabel()
        header.text = "Enter your Zendesk account details to connect the AI Agents bot."
        header.numberOfLines = 0
        header.font = .preferredFont(forTextStyle: .body)
        header.textColor = .secondaryLabel

        // Subdomain help
        let subdomainHelp = UILabel()
        subdomainHelp.text = "Find these in Zendesk Admin Center → Channels → Messaging → SDK."
        subdomainHelp.font = .preferredFont(forTextStyle: .footnote)
        subdomainHelp.textColor = .tertiaryLabel
        subdomainHelp.numberOfLines = 0

        // Auth mode
        let authLabel = makeSectionLabel("Authentication")
        authModeControl.selectedSegmentIndex = 0
        authModeControl.addTarget(self, action: #selector(authModeChanged), for: .valueChanged)

        // JWT-specific fields
        let jwtSecretLabel = makeSectionLabel("JWT Settings")
        let jwtSecretHelp = UILabel()
        jwtSecretHelp.text = "Your JWT signing server signs tokens with the secret above. Configure the same secret in Zendesk Admin Center → Channels → Messaging → Authentication."
        jwtSecretHelp.font = .preferredFont(forTextStyle: .footnote)
        jwtSecretHelp.textColor = .tertiaryLabel
        jwtSecretHelp.numberOfLines = 0

        // Save
        saveButton.configuration = {
            var c = UIButton.Configuration.filled()
            c.title = "Save & Connect"
            c.cornerStyle = .large
            c.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
            return c
        }()
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        // Error
        errorLabel.numberOfLines = 0
        errorLabel.textColor = .systemRed
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.isHidden = true

        // Help link
        helpLabel.text = "Don't have these? See SETUP.md in the project."
        helpLabel.font = .preferredFont(forTextStyle: .footnote)
        helpLabel.textColor = .tertiaryLabel
        helpLabel.numberOfLines = 0

        // Add to stack
        [header, subdomainHelp].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(8, after: header)
        stack.addArrangedSubview(makeSectionLabel("Channel"))
        stack.addArrangedSubview(channelKeyField)
        stack.addArrangedSubview(subdomainField)
        stack.setCustomSpacing(24, after: subdomainField)
        stack.addArrangedSubview(authLabel)
        stack.addArrangedSubview(authModeControl)
        stack.setCustomSpacing(24, after: authModeControl)
        stack.addArrangedSubview(jwtSecretLabel)
        stack.addArrangedSubview(jwtSecretField)
        stack.addArrangedSubview(jwtServerField)
        stack.addArrangedSubview(jwtSecretHelp)
        stack.setCustomSpacing(24, after: jwtSecretHelp)
        stack.addArrangedSubview(errorLabel)
        stack.addArrangedSubview(saveButton)
        stack.addArrangedSubview(helpLabel)

        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        authModeChanged()
    }

    private func prefillIfEditing() {
        // If credentials exist, this VC was opened from Settings — prefill
        guard let existing = credentialsStore.load() else { return }
        title = "Edit Connection"
        channelKeyField.text = existing.channelKey
        subdomainField.text = existing.subdomain
        if let idx = AuthMode.allCases.firstIndex(of: existing.authMode) {
            authModeControl.selectedSegmentIndex = idx
        }
        jwtSecretField.text = existing.jwtSigningSecret
        jwtServerField.text = existing.jwtServerBaseURL
        authModeChanged()
    }

    @objc private func authModeChanged() {
        let isJWT = AuthMode.allCases[authModeControl.selectedSegmentIndex] == .jwt
        jwtSecretField.isHidden = !isJWT
        jwtServerField.isHidden = !isJWT
        // Find the section labels by index in stack
        // (we re-arrange visually by toggling hidden)
        for view in stack.arrangedSubviews {
            if view.tag == 100 {
                view.isHidden = !isJWT
            }
        }
    }

    @objc private func saveTapped() {
        errorLabel.isHidden = true

        let channelKey = channelKeyField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let subdomain = subdomainField.text?
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".zendesk.com", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            ?? ""

        guard !channelKey.isEmpty else { return showError("Channel Key is required.") }
        guard !subdomain.isEmpty else { return showError("Subdomain is required.") }

        let mode = AuthMode.allCases[authModeControl.selectedSegmentIndex]
        var jwtSecret: String? = nil
        var jwtServer: String? = nil

        if mode == .jwt {
            jwtSecret = jwtSecretField.text?.trimmingCharacters(in: .whitespaces)
            jwtServer = jwtServerField.text?.trimmingCharacters(in: .whitespaces)
            guard let s = jwtSecret, !s.isEmpty else {
                return showError("JWT Signing Secret is required for JWT auth.")
            }
            guard let u = jwtServer, !u.isEmpty, URL(string: u) != nil else {
                return showError("JWT Server URL must be a valid URL.")
            }
        }

        let existing = credentialsStore.load()
        let creds = ZendeskCredentials(
            channelKey: channelKey,
            subdomain: subdomain,
            authMode: mode,
            jwtSigningSecret: jwtSecret,
            jwtServerBaseURL: jwtServer,
            lastVisitorName: existing?.lastVisitorName,
            lastVisitorEmail: existing?.lastVisitorEmail,
            lastVisitorExternalID: existing?.lastVisitorExternalID
        )

        do {
            try credentialsStore.save(creds)
            // SceneDelegate listens for the notification and swaps the root
        } catch {
            showError("Could not save credentials: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    // MARK: - Factory helpers

    private static func makeField(placeholder: String, secure: Bool) -> UITextField {
        let f = UITextField()
        f.placeholder = placeholder
        f.borderStyle = .roundedRect
        f.isSecureTextEntry = secure
        f.autocapitalizationType = .none
        f.autocorrectionType = .no
        f.spellCheckingType = .no
        f.smartDashesType = .no
        f.smartQuotesType = .no
        f.font = .preferredFont(forTextStyle: .body)
        f.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return f
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text.uppercased()
        l.font = .preferredFont(forTextStyle: .caption1)
        l.textColor = .secondaryLabel
        l.tag = 100
        return l
    }
}
