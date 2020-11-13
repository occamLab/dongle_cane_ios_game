//
//  BeaconTableViewCell.swift
//  MusicalCaneGame
//
//  Created by occamlab on 8/7/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import CoreLocation

class BeaconTableViewCell: UITableViewCell {

    
    @IBOutlet weak var beaconColorImage: UIImageView!
    
    @IBOutlet weak var beaconLabel: UILabel!
    
    @IBOutlet weak var beaconDistanceLabel: UILabel!
    
    @IBOutlet weak var beaconLocationLabel: UILabel!
    
    var beaconName: String?
    var beaconMinor: Int?
    var beaconColor: UIColor?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
