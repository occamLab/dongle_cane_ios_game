//
//  BeaconStackElementViewController.swift
//  MusicalCaneGame
//
//  Created by Anna Griffin on 11/13/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit

class BeaconStackElementViewController: UIViewController {

    @IBOutlet weak var beaconNameLabel: UILabel!
    @IBOutlet weak var beaconImage: UIImageView!
    
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!

    @IBOutlet weak var changeLocationButton: UIButton!
    @IBOutlet weak var addMessageButton: UIButton!
    
    @IBOutlet weak var speackButton: UIButton!
    
    var beaconNameString:String? {
        didSet {
            configureView()
        }
    }
    
    func configureView() {
        beaconNameLabel.text = beaconNameString
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
