//
//  CredentialStore.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/02/07.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import KeychainAccess
import AuthenticationServices

protocol AccountDelegate: NSObjectProtocol {
    func accountDidSignOut(_ account: Account)
}

class Account {
    enum Key: String {
        case userID
        case email
        case givenName
        case familyName
    }

    static let `default` = Account()

    weak var delegate: AccountDelegate?

    let keychain = Keychain()

    var userID: String? {
        return get(.userID)
    }

    var email: String? {
        return get(.email)
    }

    var givenName: String? {
        return get(.givenName)
    }

    var familyName: String? {
        return get(.familyName)
    }

    init() {
        NotificationCenter.default.addObserver(forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil, queue: nil) { (notification) in
            self.delegate?.accountDidSignOut(self)
        }
    }

    func checkSignInState(completionHandler: @escaping (Bool) -> Void) {
        guard let userID = userID else {
            completionHandler(false)
            return
        }

        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { (credentialState, error) in
            DispatchQueue.main.async {
                switch credentialState {
                case .revoked, .notFound:
                    completionHandler(false)
                default:
                    completionHandler(true)
                }
            }
        }
    }

    func save(credential: ASAuthorizationAppleIDCredential) throws {
        try set(credential.user, for: .userID)
        try setIfPresent(credential.email, for: .email)
        try setIfPresent(credential.fullName?.givenName, for: .givenName)
        try setIfPresent(credential.fullName?.familyName, for: .familyName)
    }

    func clear() throws {
        try keychain.removeAll()
    }

    private func get(_ key: Key) -> String? {
        return keychain[key.rawValue]
    }

    private func set(_ value: String, for key: Key) throws {
        try keychain.set(value, key: key.rawValue)
    }

    private func setIfPresent(_ value: String?, for key: Key) throws {
        guard let value = value else { return }
        try keychain.set(value, key: key.rawValue)
    }
}
