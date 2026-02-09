//
//  MainViewController.swift
//  MusicalCaneGame
//
//  Created by Anna Griffin on 10/5/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import SwiftUI
import FirebaseCore

class MainViewController: UITableViewController, AuthManagerDelegate {
    @IBOutlet weak var signInWithAppleContainer: UIView!
    let dbInterface = DBInterface.shared
    var signInViewModal: SignInViewController?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Do any additional setup after loading the view.
        if FirebaseManager.shared.currentUID == nil {
            AuthManager.shared.delegate = self
            signInViewModal = SignInViewController()
            signInViewModal!.modalPresentationStyle = .overFullScreen
            present(signInViewModal!, animated: true, completion: nil)
        } else {
            // uncomment to test sign-in flow
            //   AuthManager.shared.signOut()
        }
    }
    
    func didSuccessfullySignIn() {
        signInViewModal?.dismissModal()
    }
}

class SignInViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        // Main content container
        let contentView = UIView()
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 12
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentView.widthAnchor.constraint(equalToConstant: 300),
            contentView.heightAnchor.constraint(equalToConstant: 200)
        ])

        // Explanation label
        let explanationLabel = UILabel()
        explanationLabel.text = "Sign in to save your student profiles and student data securely."
        explanationLabel.textAlignment = .center
        explanationLabel.numberOfLines = 0
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(explanationLabel)

        // Apple Sign-In Button (wrapped SwiftUI view)
        let signInButtonVC = UIHostingController(
            rootView: SignInWithApple()
                .onTapGesture(perform: AuthManager.shared.startSignInWithAppleFlow)
        )
        addChildViewController(signInButtonVC)
        signInButtonVC.didMove(toParent: self)
        signInButtonVC.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(signInButtonVC.view)

        // Constraints
        NSLayoutConstraint.activate([
            explanationLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            explanationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            explanationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            signInButtonVC.view.topAnchor.constraint(equalTo: explanationLabel.bottomAnchor, constant: 40),
            signInButtonVC.view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            signInButtonVC.view.heightAnchor.constraint(equalToConstant: 44),
            signInButtonVC.view.widthAnchor.constraint(equalToConstant: 200)
        ])
    }

    @objc func dismissModal() {
        dismiss(animated: true, completion: nil)
    }
}
