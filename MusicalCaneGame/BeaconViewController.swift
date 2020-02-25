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
    let metersToFeet = Float(100.0/2.54/12)
    var voiceNoteToPlay: AVAudioPlayer?
    let dbInterface = DBInterface.shared
    var isRecordingAudio = false
    let synth = AVSpeechSynthesizer()
    
    var unknownBeaconMinors: [Int] = []

    var beacons: [Int] {
        print("known beacons", dbInterface.getBeaconMinors().sorted())
        return dbInterface.getBeaconMinors().sorted() + unknownBeaconMinors.sorted()
    }

    var distanceDict:[Int:Double] = [:]

   
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var beaconsEnabledSwitch: UISwitch!
    
    
    
    var threshold: Float = 5.0
    @IBOutlet weak var thresholdLabel: UILabel!
    @IBAction func thresholdSlider(_ sender: UISlider) {
        threshold = sender.value
        thresholdLabel.text = String(Double(sender.value).roundTo(places: 2)) + " feet"
    }
    
    var newLocation:(Beacon: String?,Location: String?)
    
    @IBAction func enableBeaconsSwitchToggled(_ sender: UISwitch) {
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        dbInterface.updateBeaconsEnabled(u_name: selectedProfile, enabled: sender.isOn)
    }
    
    
    let locationManager = CLLocationManager()
    let region = CLBeaconRegion(proximityUUID: NSUUID(uuidString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D")! as UUID, identifier: "Estimotes")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //The new method should only use User defaults to know what the current profile is
        if (UserDefaults.standard.string(forKey: "currentProfile") == nil){
            UserDefaults.standard.set("Default User", forKey: "currentProfile")
        }

        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleNewLocation(notification:)), name: NSNotification.Name(rawValue: "setBeaconDestination"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleNewBeaconStatus(notification:)), name: NSNotification.Name(rawValue: "setBeaconStatus"), object: nil)

        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleChangeInAudioRecording(notification:)), name: NSNotification.Name(rawValue: "handleChangeInAudioRecording"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleBeaconGlobalNameChange(notification:)), name: NSNotification.Name(rawValue: "setGlobalBeaconName"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleBeaconGlobalColorChange(notification:)), name: NSNotification.Name(rawValue: "setBeaconColor"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleForgetBeacon(notification:)), name: NSNotification.Name(rawValue: "forgetBeacon"), object: nil)

        // Do any additional setup after loading the view, typically from a nib.
       
        locationManager.delegate = self
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startRangingBeacons(in: region)
        
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        if let row = dbInterface.getRow(u_name: selectedProfile) {
            beaconsEnabledSwitch.isOn = try! row.get(dbInterface.beacons_enabled)
        }

    }
    
    @objc func handleNewLocation(notification: NSNotification) {
        if let fields = notification.object as? Dictionary<String, Any> {
            setNewLocation(forBeacon: fields["forBeacon"] as! Int, location: fields["location"] as! String)
        }
    }
    
    @objc func handleBeaconGlobalNameChange(notification: NSNotification) {
        if let fields = notification.object as? Dictionary<String, Any> {
            setNewGlobalName(forBeacon: fields["forBeacon"] as! Int, globalName: fields["globalName"] as! String)
        }
    }
    
    @objc func handleBeaconGlobalColorChange(notification: NSNotification) {
        if let fields = notification.object as? Dictionary<String, Any> {
            setNewGlobalBeaconColor(forBeacon: fields["forBeacon"] as! Int, hexCode: fields["colorHexValue"] as! String)
        }
    }
    
    @objc func handleNewBeaconStatus(notification: NSNotification) {
        if let fields = notification.object as? Dictionary<String, Any> {
            setNewBeaconStatus(forBeacon: fields["forBeacon"] as! Int, status: fields["status"] as! Int)
        }
    }
    
    @objc func handleForgetBeacon(notification: NSNotification) {
        if let fields = notification.object as? Dictionary<String, Any> {
            forgetBeacon(forBeacon: fields["forBeacon"] as! Int)
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
    
    func forgetBeacon(forBeacon: Int) {
        dbInterface.forgetBeacon(b_minor: forBeacon)
    }
    
    func setNewLocation(forBeacon: Int, location: String) {
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        dbInterface.updateBeaconLocation(u_name: selectedProfile, b_minor: forBeacon, location_text: location)
        
        tableView?.reloadData()
    }
    
    func setNewBeaconStatus(forBeacon: Int, status: Int) {
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        dbInterface.updateBeaconStatus(u_name: selectedProfile, b_minor: forBeacon, status: status)
        tableView?.reloadData()
    }
    
    func setNewGlobalName(forBeacon: Int, globalName: String) {
        dbInterface.updateGlobalBeaconName(b_minor: forBeacon, b_name: globalName)
        tableView?.reloadData()
    }
    
    func setNewGlobalBeaconColor(forBeacon: Int, hexCode: String) {
        dbInterface.updateGlobalBeaconColorHexCode(b_minor: forBeacon, b_hex_code: hexCode)
        tableView?.reloadData()
    }
}



extension BeaconViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beaconsScanned: [CLBeacon], in region: CLBeaconRegion) {
        let knownBeacons = beaconsScanned.filter{ $0.proximity != CLProximity.unknown }
        let beaconsSeen = Dictionary<Int, CLBeacon>(uniqueKeysWithValues: zip(knownBeacons.map({Int(truncating: $0.minor)}), knownBeacons))
        let knownBeaconMinors = dbInterface.getBeaconMinors()
        
        unknownBeaconMinors = Array(Set(beaconsSeen.keys).subtracting(knownBeaconMinors))
        distanceDict = [:]
        for minor in beacons {
            if let beacon = beaconsSeen[minor] {
                distanceDict[minor] = beacon.accuracy
            } else {
                distanceDict[minor] = -1.0
            }
        }

        tableView?.reloadData()
    }
}

func hexStringToUIColor (hex:String) -> UIColor {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }

    if ((cString.count) != 6) {
        return UIColor.gray
    }

    var rgbValue:UInt64 = 0
    Scanner(string: cString).scanHexInt64(&rgbValue)

    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}


extension BeaconViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return beacons.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? BeaconTableViewCell else {
              return
        }
        guard let popoverContent = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "locationpopupview") as? LocationPopUpViewController else {
            return
        }
        
        //says that the recorder should dismiss itself when it is done
        popoverContent.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: popoverContent, action: #selector(popoverContent.dismissWindow))
        let nav = UINavigationController(rootViewController: popoverContent)
        nav.modalPresentationStyle = .popover
        let popover = nav.popoverPresentationController
        popover?.sourceView = self.view
        popover?.sourceRect = CGRect(x: 0, y: 10, width: 0,height: 0)
        popoverContent.selectedBeacon = cell.beaconName
        popoverContent.selectedMinor = cell.beaconMinor
        popoverContent.selectedColor = cell.beaconColor
        self.present(nav, animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! BeaconTableViewCell
        let currentBeacon:String
        let beaconColor:UIColor
        let currentMinor = beacons[indexPath.row]
        let isUnknown:Bool
        if let beaconName = dbInterface.getGlobalBeaconName(b_minor: currentMinor) {
            currentBeacon = beaconName
            isUnknown = false
        } else {
            currentBeacon = "Unknown"
            isUnknown = true
        }
        if let colorHexCode = dbInterface.getGlobalBeaconColorHexCode(b_minor: currentMinor) {
            beaconColor = hexStringToUIColor(hex: colorHexCode)
        } else {
            beaconColor = UIColor.white
        }
        cell.beaconName = currentBeacon
        cell.beaconMinor = currentMinor
        cell.beaconColor = beaconColor

        cell.beaconColorImage.image = UIImage(named: ("White.jpg"))?.withRenderingMode(.alwaysTemplate)
        cell.beaconColorImage.tintColor = beaconColor
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        cell.beaconLabel.text = currentBeacon + ":"

        let row = dbInterface.getBeaconNames(u_name: selectedProfile, b_minor: currentMinor)
        if let row = row, row[dbInterface.beaconStatus] == 2 { // TODO: bad magic number!
            cell.contentView.backgroundColor = .gray
        } else {
            cell.contentView.backgroundColor = .groupTableViewBackground
        }
        
        if let currDistance = distanceDict[currentMinor], currDistance >= 0 {
            cell.beaconDistanceLabel.text = String(format: "%0.2f feet", currDistance*Double(metersToFeet))
        } else {
            cell.beaconDistanceLabel.text = "Unknown distance"
        }
        
        let beaconInfo = dbInterface.getBeaconNames(u_name: selectedProfile, b_minor: currentMinor)

        if !isUnknown, let thisBeaconInfo = beaconInfo {
            try! cell.beaconLocationLabel.text = thisBeaconInfo.get(dbInterface.locationText)
        } else {
            cell.beaconLocationLabel.text = ""
        }
        
        if !isUnknown, !isRecordingAudio, beaconsEnabledSwitch.isOn, let distanceToCurrent = distanceDict[currentMinor], Float(distanceToCurrent)*metersToFeet <= threshold && Float(distanceDict[currentMinor]!) >= Float(0.0), let beaconInfo = beaconInfo {
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
                        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [.duckOthers,.interruptSpokenAudioAndMixWithOthers])
                        voiceNoteToPlay?.volume = 1.0
                        voiceNoteToPlay?.play()
                    }
                } else if try beaconInfo.get(dbInterface.beaconStatus) == 0 && !beaconInfo.get(dbInterface.locationText).isEmpty {
                    // make sure we're not currently speaking
                    if !synth.isSpeaking {
                        let utterance = AVSpeechUtterance(string: try  beaconInfo.get(dbInterface.locationText))
                        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                        utterance.rate = 0.5
                        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [.duckOthers,.interruptSpokenAudioAndMixWithOthers])
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


