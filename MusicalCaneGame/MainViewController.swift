//
//  MainViewController.swift
//  MusicalCaneGame
//
//  Created by Anna Griffin on 10/5/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import SwiftUI

class MainViewController: UIViewController {

    @IBOutlet weak var signInWithAppleContainer: UIView!
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        // Do any additional setup after loading the view.
        let signInView = UIHostingController(rootView: SignInWithApple().onTapGesture(perform: AuthManager.shared.startSignInWithAppleFlow))
        addChildViewController(signInView)
        signInView.view.frame = signInWithAppleContainer.bounds
        signInWithAppleContainer.addSubview(signInView.view)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func sideMenu() {
        
        if revealViewController() != nil {
            
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            revealViewController().rearViewRevealWidth = 250
            
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
            
        }
    }
}
