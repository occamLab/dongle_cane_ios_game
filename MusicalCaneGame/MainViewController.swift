//
//  MainViewController.swift
//  MusicalCaneGame
//
//  Created by Anna Griffin on 10/5/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import SwiftUI

class MainViewController: UITableViewController {
    @IBOutlet weak var signInWithAppleContainer: UIView!
    // force load early
    let dbInterface = DBInterface.shared
}
