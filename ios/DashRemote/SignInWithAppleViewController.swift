//
//  SignInWithAppleViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/02/07.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import AuthenticationServices

class SignInWithAppleViewController: UIViewController, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @IBOutlet weak var verticalStackView: UIStackView!

    let buttonHeight: CGFloat = 50

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpSignInWithAppleButton()
    }

    func setUpSignInWithAppleButton() {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .whiteOutline)

        button.addTarget(self, action: #selector(signInWithAppleButtonDidTap), for: .touchUpInside)

        // It seems the button does not use this value as-is and
        // automatically switches between round and rounded corner.
        button.cornerRadius = buttonHeight

        verticalStackView.addArrangedSubview(button)

        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: buttonHeight),
            button.leadingAnchor.constraint(equalTo: verticalStackView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: verticalStackView.trailingAnchor),
        ])
    }

    @objc func signInWithAppleButtonDidTap() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        try! Account.default.save(credential: credential)
        dismiss(animated: true)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
