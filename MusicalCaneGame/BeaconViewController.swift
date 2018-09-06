//
//  BeaconViewController.swift
//  MusicalCaneGame
//
//  Created by occamlab on 8/7/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation

class BeaconViewController: UIViewController {
    
    let beacons = ["Blue", "Pink", "Purple", "Rose", "White", "Yellow"]

    
    
    let colorsToMinors:[String:NSNumber] = ["Yellow": 33334,
                                            "Pink": 6103,
                                            "Rose": 4724,
                                            "Blue": 7567,
                                            "White": 56186,
                                            "Purple": 11819]
    
    var distanceDict:[NSNumber:Double] = [33334: -1.0,
                                      6103: -1.0,
                                      4724: -1.0,
                                      7567: -1.0,
                                      56186: -1.0,
                                      11819: -1.0]
    
    var locationDict:[NSNumber:String] = [33334: "",
                                      6103: "",
                                      4724: "",
                                      7567: "",
                                      56186: "",
                                      11819: ""]
    

   
    @IBOutlet weak var tableView: UITableView!
        
    
    
    var threshold: Float = 2.5
    @IBOutlet weak var thresholdLabel: UILabel!
    @IBAction func thresholdSlider(_ sender: UISlider) {
        thresholdLabel.text = String(sender.value)
        threshold = sender.value
    }
    
    var newLocation:(Beacon: String?,Location: String?)
    

    
    let locationManager = CLLocationManager()
    let region = CLBeaconRegion(proximityUUID: NSUUID(uuidString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D")! as UUID, identifier: "Estimotes")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
       
        locationManager.delegate = self
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startRangingBeacons(in: region)
        
        
        // get the locations from UserDefaults
        let userDefaults: UserDefaults = UserDefaults.standard
        for (key, _) in locationDict {
            let matchingColors = colorsToMinors.filter {$0.value == key}
            let color = matchingColors.keys.first
            if let location = userDefaults.string(forKey: color!) {
                locationDict[key] = location
            }
        }
    }
    
    func setNewLocation(forBeacon: String, location: String) {
        locationDict[colorsToMinors[forBeacon]!] = location
        // store the location in UserDefaults
        
        let userDefaults: UserDefaults = UserDefaults.standard
        userDefaults.set(location, forKey: forBeacon)

//        var tempArray:[String] = []
//
//        for (_, location) in locationDict {
//            tempArray.append(location)
//        }
//        print(tempArray)
//
//        let userDefaults: UserDefaults = UserDefaults.standard
//        userDefaults.set(tempArray, forKey: "locations")
//
        
        tableView?.reloadData()
    }
    

    
    
}



extension BeaconViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        let knownBeacons = beacons.filter{ $0.proximity != CLProximity.unknown }
        var knownBeaconMinors:[NSNumber:Double] = [:]

        if (knownBeacons.count > 0) {
//            print(knownBeacons)
            for each in knownBeacons {
                knownBeaconMinors[each.minor] = each.accuracy
            }
            
            for (minor, _) in distanceDict {
                if knownBeaconMinors.keys.contains(minor) {
                    distanceDict[minor] = knownBeaconMinors[minor]
                } else {
                    distanceDict[minor] = -1.0
                }
            }
            tableView?.reloadData()
        }
    }
}

extension BeaconViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return beacons.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! BeaconTableViewCell
        let currentBeacon = beacons[indexPath.row]
        
        cell.beaconColorImage.image = UIImage(named: (currentBeacon + ".jpg"))
        cell.beaconLabel.text = currentBeacon + ":"
        
        
        let currentMinor = colorsToMinors[currentBeacon]
        if distanceDict[currentMinor!] == -1 {
            cell.beaconDistanceLabel.text = "Unknown"
        } else {
            cell.beaconDistanceLabel.text = String(format: "%f", distanceDict[currentMinor!]!)
        }
        print(currentMinor, distanceDict[currentMinor!]!)
        if Float(distanceDict[currentMinor!]!) <= threshold && Float(distanceDict[currentMinor!]!) > Float(0.0) {
            let synth = AVSpeechSynthesizer()
            let utterance = AVSpeechUtterance(string: locationDict[currentMinor!]!)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.5
            synth.speak(utterance)
        }
        
        
        cell.beaconLocationLabel.text = locationDict[currentMinor!]
//        print(locationDict)

        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(75)
        
    }
}


