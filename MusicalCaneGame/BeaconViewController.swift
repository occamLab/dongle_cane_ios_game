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
    
    let beacons = ["Blue", "Purple", "Rose", "White"]
    var voiceNoteToPlay: AVAudioPlayer?
    let dbInterface = DBInterface.shared
    var isRecordingAudio = false
    let synth = AVSpeechSynthesizer()
    
    let colorsToMinors:[String:NSNumber] = ["Rose": 4724,
                                            "Blue": 7567,
                                            "White": 56186,
                                            "Purple": 11819]
    
    var distanceDict:[NSNumber:Double] = [4724: -1.0,
                                      7567: -1.0,
                                      56186: -1.0,
                                      11819: -1.0]
    
    var locationDict:[NSNumber:String] = [4724: "",
                                      7567: "",
                                      56186: "",
                                      11819: ""]
    

   
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var beaconsEnabledSwitch: UISwitch!
    
    
    
    var threshold: Float = 2.5
    @IBOutlet weak var thresholdLabel: UILabel!
    @IBAction func thresholdSlider(_ sender: UISlider) {
        thresholdLabel.text = String(sender.value)
        threshold = sender.value
    }
    
    var newLocation:(Beacon: String?,Location: String?)
    
    @IBAction func enableBeaconsSwitchToggled(_ sender: UISwitch) {
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        dbInterface.updateBeaconsEnabled(u_name: selectedProfile, enabled: sender.isOn)
        print("toggled")
    }
    
    
    let locationManager = CLLocationManager()
    let region = CLBeaconRegion(proximityUUID: NSUUID(uuidString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D")! as UUID, identifier: "Estimotes")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleNewLocation(notification:)), name: NSNotification.Name(rawValue: "setBeaconDestination"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleChangeInAudioRecording(notification:)), name: NSNotification.Name(rawValue: "handleChangeInAudioRecording"), object: nil)

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
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        let row = dbInterface.getRow(u_name: selectedProfile)
        if let row = row {
            beaconsEnabledSwitch.isOn = try! row.get(dbInterface.beacons_enabled)
        }

    }
    
    @objc func handleNewLocation(notification: NSNotification) {
        if let fields = notification.object as? Dictionary<String, String> {
            setNewLocation(forBeacon: fields["forBeacon"]!, location: fields["location"]!)
        }
    }
    
    @objc func handleChangeInAudioRecording(notification: NSNotification) {
        if let recordingStatus = notification.object as? Bool {
            isRecordingAudio = recordingStatus
            if isRecordingAudio {
                // stop any audio that is currently running
                voiceNoteToPlay?.stop()
                synth.stopSpeaking(at: .immediate)
            }
        }
    }
    
    func setNewLocation(forBeacon: String, location: String) {
        locationDict[colorsToMinors[forBeacon]!] = location
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        dbInterface.updateBeaconLocation(u_name: selectedProfile, b_name: forBeacon, location_text: location)
        
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? BeaconTableViewCell else {
              return
        }
        guard let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "locationpopupview") as? LocationPopUpViewController else {
            return
        }
        // TODO add a dismiss button
        // Use the popover presentation style for your view controller.
        viewController.modalPresentationStyle = .popover
        viewController.selectedBeacon = cell.beaconName

        self.present(viewController, animated: true)
        //viewController.beaconTextField.text = cell.beaconLabel.text
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! BeaconTableViewCell
        let currentBeacon = beacons[indexPath.row]
        cell.beaconName = currentBeacon
        cell.beaconColorImage.image = UIImage(named: (currentBeacon + ".jpg"))
        
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        cell.beaconLabel.text = currentBeacon + ":"

        let row = dbInterface.getBeaconNames(u_name: selectedProfile, b_name: currentBeacon)
        if let row = row, row[dbInterface.beaconStatus] == 2 { // TODO: bad magic number!
            cell.contentView.backgroundColor = .gray
        } else {
            cell.contentView.backgroundColor = .groupTableViewBackground
        }
        
        let currentMinor = colorsToMinors[currentBeacon]
        if distanceDict[currentMinor!] == -1 {
            cell.beaconDistanceLabel.text = "Unknown"
        } else {
            cell.beaconDistanceLabel.text = String(format: "%f", distanceDict[currentMinor!]!)
        }
        
        let beaconInfo = dbInterface.getBeaconNames(u_name: selectedProfile, b_name: currentBeacon)

        if let thisBeaconInfo = beaconInfo {
            try! cell.beaconLocationLabel.text = thisBeaconInfo.get(dbInterface.locationText)
        } else {
            cell.beaconLocationLabel.text = ""
        }
        
        if !isRecordingAudio, beaconsEnabledSwitch.isOn, Float(distanceDict[currentMinor!]!) <= threshold && Float(distanceDict[currentMinor!]!) > Float(0.0), let beaconInfo = beaconInfo {
            do {
                if try beaconInfo.get(dbInterface.beaconStatus) == 1 && !beaconInfo.get(dbInterface.voiceNoteURL).isEmpty {
                    if voiceNoteToPlay == nil || !voiceNoteToPlay!.isPlaying {
                        let voiceNoteFile = try beaconInfo.get(dbInterface.voiceNoteURL)
                        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in:.userDomainMask).first!
                        let voiceNoteURL = documentsUrl.appendingPathComponent(voiceNoteFile)
                        let data = try Data(contentsOf: voiceNoteURL)
                        print(data)
                        voiceNoteToPlay = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.caf.rawValue)
                        
                        voiceNoteToPlay?.prepareToPlay()
                        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                        try AVAudioSession.sharedInstance().setActive(true)
                        voiceNoteToPlay?.volume = 1.0
                        voiceNoteToPlay?.play()
                    }
                } else if try beaconInfo.get(dbInterface.beaconStatus) == 0 && !beaconInfo.get(dbInterface.locationText).isEmpty {
                    // make sure we're not currently speaking
                    if !synth.isSpeaking {
                        let utterance = AVSpeechUtterance(string: try  beaconInfo.get(dbInterface.locationText))
                        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                        utterance.rate = 0.5
                        synth.speak(utterance)
                    }
                }
            } catch {
                print("Error info: \(error)")
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(75)
        
    }
}


