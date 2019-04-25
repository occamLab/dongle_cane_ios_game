//
//  MusicViewController.swift
//  MusicalCaneGame
//
//  Created by Anna Griffin on 10/5/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation
import MediaPlayer
import CoreLocation

let dongleSensorCBUUID = CBUUID(string: "2ea7")
let sensorFusionCharacteristicCBUUID = CBUUID(string: "2ea78970-7d44-44bb-b097-26183f402407")
let sweepNotificationKey = "cane.sweep.notification"

class MusicViewController: UIViewController, UICollisionBehaviorDelegate {
    //Declare db to load options
    let dbInterface = DBInterface()
    let sensorManager = SensorManager()
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var playerName: UILabel!
    
    //For Beacons
    let locationManager = CLLocationManager()
    let region = CLBeaconRegion(proximityUUID: NSUUID(uuidString: "8492E75F-4FD6-469D-B132-043FE94921D8")! as UUID, identifier: "Estimotes")
    // 8492E75F-4FD6-469D-B132-043FE94921D8
    // B9407F30-F5F8-466E-AFF9-25556B57FE6D
    
    let beacons = ["Blue", "Pink", "Purple", "Rose", "White", "Yellow"]
    
    var viewsBeacons = [UIView]()
    var animator:UIDynamicAnimator!
    var gravity:UIGravityBehavior!
    var snap:UISnapBehavior!
    var previousTouchPoint:CGPoint!
    var viewDragging = false
    var viewPinned = false
    
    var offset:CGFloat = 100
    var knownBeaconMinorsStrings:[String] = []

    //Declare variables that are loaded from profile
    var selectedProfile:String = "Default User"
    var selectedSongStr: String = "Select Music"
    var selectedBeepStr: String = "Select Beep"
    var sweepRange: Float = 1.0
    var caneLength: Float = 1.0
    var beepCount: Int = 10
    var sweepTolerance: Float = 20
    //Other important variable(s) not explicitly loaded from db
    var selectedSong:URL?
    //For debugging purposes
    func loadProfile(){
        let user_row = self.dbInterface.getRow(u_name: selectedProfile)
        playerName.text = selectedProfile
        //Change beep noise
        selectedBeepStr = String(user_row![self.dbInterface.beep_noise])

        //Change Music Title
        selectedSongStr = String(user_row![self.dbInterface.music])
        
        if(selectedSongStr != "Select Music"){
            selectedSong = URL.init(string: user_row![self.dbInterface.music_url])
            songTitleLabel.text = selectedSongStr
        }else{
            songTitleLabel.text = "Please select song on manage profiles screen"
        }
        
        //For the sliders
        sweepTolerance = Float(user_row![self.dbInterface.sweep_tolerance])
        beepCount = Int(user_row![self.dbInterface.beep_count])
        sweepRange = Float(user_row![self.dbInterface.sweep_width])
        sweepRangeLabel.text = String(sweepRange)
        sweepRangeSliderUI.setValue(sweepRange, animated: false)

        caneLength = Float(user_row![self.dbInterface.cane_length])
    }
    
    //Sweep Range for dynamic adjustment
    @IBOutlet weak var sweepRangeLabel: UILabel!
    @IBOutlet weak var sweepRangeSliderUI: UISlider!
    @IBAction func sweepRangeSlider(_ sender: UISlider) {
        let x = Double(sender.value).roundTo(places: 2)
        sweepRangeLabel.text = String(x)
        sweepRange = sender.value
    }
    
    
    var activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView()
    //To start the session
    @IBOutlet weak var controlButton: UIBarButtonItem!
    var startButtonPressed:Bool? = false
    @IBAction func controlButton(_ sender: Any) {
        
        if controlButton.title == "Start" {
            if selectedSong != nil {
                
                activityIndicator.center = self.view.center
                activityIndicator.hidesWhenStopped = true
                activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
                view.addSubview(activityIndicator)
                
                activityIndicator.startAnimating()
                UIApplication.shared.beginIgnoringInteractionEvents()
                
                let synth = AVSpeechSynthesizer()
                let utterance = AVSpeechUtterance(string: "Connecting")
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.6
                synth.speak(utterance)
                
                centralManager = CBCentralManager(delegate: self, queue: nil)
                startButtonPressed = true // music mode has started
                
            } else {
                createAlert(title: "Error", message: "Not all required fields are complete")
                
            }
        } else if controlButton.title == "Stop" {
            centralManager.cancelPeripheralConnection(dongleSensorPeripheral)
            //  forget when i reest temp? here, maybe i should make it nil instead? also, i should rename because I already have temp in this file
            startButtonPressed = false
            audioPlayer?.stop()
            
            // text to speech
            let synth = AVSpeechSynthesizer()
            let utterance = AVSpeechUtterance(string: "Disconnected")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.6
            synth.speak(utterance)
            controlButton.title = "Start"
            print("stop button pressed")
     
        }
        
    }
    //Start beacon code
    func createAlert (title:String, message:String) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sideMenu()
        //To be deleted. Load the song from user defaults
//        selectedSong = UserDefaults.standard.url(forKey: "mySongURL")
//        songTitleLabel.text = UserDefaults.standard.string(forKey: "mySongTitle")
        //The new method should only use User defaults to know what the current profile is
        if (UserDefaults.standard.string(forKey: "currentProfile") == nil){
            UserDefaults.standard.set("Default User", forKey: "currentProfile")
        }
        selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        loadProfile()
        
        createObservers()
        //For beacons
        locationManager.delegate = self
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startRangingBeacons(in: region)

        animator = UIDynamicAnimator(referenceView: self.view)
        gravity = UIGravityBehavior()
        
        animator.addBehavior(gravity)
        gravity.magnitude = 4
        
    }
    
    func addViewController (atOffset offset:CGFloat, dataForVC data:AnyObject?) -> UIView? {
        
        let frameForView = self.view.bounds.offsetBy(dx: 0, dy: self.view.bounds.size.height - offset)
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let stackElementVC = sb.instantiateViewController(withIdentifier: "StackElement") as! BeaconStackElementViewController
        
        if let view = stackElementVC.view {
            view.frame = frameForView
            view.layer.cornerRadius = 5
            view.layer.shadowOffset = CGSize(width: 2, height: 2)
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowRadius = 3
            view.layer.shadowOpacity = 0.5
            
            if let headingString = data as? String {
                stackElementVC.beaconNameString = headingString
            }
            
            self.addChildViewController(stackElementVC)
            self.view.addSubview(view)
            stackElementVC.didMove(toParentViewController: self)
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MusicViewController.handlePan(gestureRecognizer: )))
            view.addGestureRecognizer(panGestureRecognizer)
            
            let collision = UICollisionBehavior(items: [view])
            collision.collisionDelegate = self
            animator.addBehavior(collision)
            
            let boundry = view.frame.origin.y + view.frame.size.height
            var boundryStart = CGPoint(x: 0, y: boundry)
            var boundryEnd = CGPoint(x: self.view.bounds.size.width, y: boundry)
            collision.addBoundary(withIdentifier: 1 as NSCopying, from:boundryStart, to: boundryEnd)
            
            boundryStart = CGPoint(x: 0, y: 0)
            boundryEnd = CGPoint(x: self.view.bounds.size.width, y: 0)
            collision.addBoundary(withIdentifier: 2 as NSCopying, from:boundryStart, to: boundryEnd)
            
            gravity.addItem(view)
            let itemBehavior = UIDynamicItemBehavior(items: [view])
            animator.addBehavior(itemBehavior)
            
            return view
        }
        return nil
        
    }

    @objc func handlePan (gestureRecognizer:UIPanGestureRecognizer) {
        
        let touchPoint = gestureRecognizer.location(in: self.view)
        let draggedView = gestureRecognizer.view!
        
        if gestureRecognizer.state == .began {
            let dragStartPoint = gestureRecognizer.location(in: draggedView)
            if dragStartPoint.y < 200 {
                viewDragging = true
                previousTouchPoint = touchPoint
            }
        } else if gestureRecognizer.state == .changed && viewDragging {
            let yOffset = previousTouchPoint.y - touchPoint.y
            
            draggedView.center = CGPoint(x: draggedView.center.x, y: draggedView.center.y - yOffset)
            previousTouchPoint = touchPoint
        } else if gestureRecognizer.state == .ended && viewDragging {
            
            pin(view: draggedView)
            //velocity
            
            animator.updateItem(usingCurrentState: draggedView)
            viewDragging = false
        }
        
    }
    
    func pin (view:UIView) {
        
        // how far user has to drag upwards for it to pin
        let viewHadReachedPinLocation = view.frame.origin.y < 400
        if viewHadReachedPinLocation {
            if !viewPinned {
                var snapPosition = self.view.center
                // how far down it snaps
                snapPosition.y += 400
                
                snap = UISnapBehavior(item: view, snapTo: snapPosition)
                animator.addBehavior(snap)
                setVisibility(view: view, alpha: 0)
                
                
                viewPinned = true
            }
        } else {
            if viewPinned {
                animator.removeBehavior(snap)
                setVisibility(view: view, alpha: 1)
                
                viewPinned = false
            }
        }
    }
    
    func setVisibility (view:UIView, alpha:CGFloat) {
        
        for aView in viewsBeacons {
            if aView != view {
                aView.alpha = alpha
            }
        }
    }
    
    func addVelocity (toView view:UIView, fromGestureRecognizer panGesture:UIPanGestureRecognizer) {
        var velocity = panGesture.velocity(in: self.view)
        velocity.x = 0
        
        if let behavior = itemBehavior(forView: view) {
            behavior.addLinearVelocity(velocity, for:view)
        }
        
    }
    
    func itemBehavior (forView view:UIView) -> UIDynamicItemBehavior? {
        
        for behavior in animator.behaviors {
            if let itemBehavior = behavior as? UIDynamicItemBehavior {
                if let possibleView = itemBehavior.items.first as? UIView, possibleView == view {
                    return itemBehavior
                }
            }
        }
        return nil
    }
    
    func collisionBehavior(_ behavior: UICollisionBehavior, endedContactFor item: UIDynamicItem, withBoundaryIdentifier identifier: NSCopying?) {
        if NSNumber(integerLiteral: 2).isEqual(identifier){
            let view = item as! UIView
            pin(view: view)
            
        }
    }
    //End becaons
    
    func sideMenu() {
        
        if revealViewController() != nil {
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            revealViewController().rearViewRevealWidth = 250
        view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        }
    }
    //Variable Declaration
    var centralManager: CBCentralManager!
    var dongleSensorPeripheral: CBPeripheral!
    
    var audioPlayer: AVAudioPlayer?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    
    
    let sweep = Notification.Name(rawValue: sweepNotificationKey)
    
    var startSweep = true
    var startDir:[Float] = []
    var anglePrev:Float = 0.0
    
    var beginningMusic = true
    var sweepTime:Float = 2.0
    
    var playing = -1
    var shouldPlay = -1
    
    var stopMusicTimer:Timer?
    
    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(MusicViewController.processSweeps (notification:)), name: sweep, object: nil)
    }
    
    @objc func processSweeps(notification: NSNotification) {
        
        if (!startButtonPressed!){ return}
        let sweepDistance = notification.object as! Float
        let is_valid_sweep = (sweepDistance > sweepRange - sweepTolerance) && (sweepDistance < sweepRange + sweepTolerance)
        // if we've turned around and we want to play music
        if is_valid_sweep{
            // we should play music
            shouldPlay = 1
            print("SweepRange: ", sweepRange)
            
            // create a new timer in case a sweep takes too long?
//            stopMusicTimer?.invalidate()
//            stopMusicTimer = Timer.scheduledTimer(timeInterval: TimeInterval(sweepTolerance), target: self, selector: #selector(stopPlaying), userInfo: nil, repeats: true)
            // music has stopped but we want to restart it?
            if playing != shouldPlay {
                if beginningMusic == true {
                    if selectedSong != nil {
                        do {
                            audioPlayer = try AVAudioPlayer(contentsOf: selectedSong! as URL)
                        } catch {
                            print("oh no")
                        }
                    } else {
                        createAlert(title: "Error", message: "Could not find song address on device. Make sure it is on your device, not in you iClound library")
                        print("error")
                    }
                    beginningMusic = false
                }
                
                audioPlayer?.play()
                audioPlayer?.numberOfLoops = -1
                playing = 1
            }
        } else{
        // stop music
            
            stopPlaying()
        }
    }
    
    // stops music from playing
    @objc func stopPlaying() {
        shouldPlay = -1
        if playing >= 0 {
            audioPlayer?.pause()
            playing = -1
        }
    }

}

//extension Double {
//    func roundTo(places:Int) -> Double {
//        let divisor = pow(10.0, Double(places))
//        return (self*divisor).rounded() / divisor
//    }
//}

extension MusicViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
        case .unknown:
            1==2
        case .resetting:
            1==2
        case .unsupported:
            1==2
        case .unauthorized:
            1==2
        case .poweredOff:
            1==2
        case .poweredOn:
            1==2
            centralManager.scanForPeripherals(withServices: [dongleSensorCBUUID])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        dongleSensorPeripheral = peripheral
        dongleSensorPeripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(dongleSensorPeripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        dongleSensorPeripheral.discoverServices(nil)
    }
}

extension MusicViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) {
                var rawArray:[UInt8] = [0x01]
                let data = NSData(bytes: &rawArray, length: rawArray.count)
                peripheral.writeValue(data as Data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        activityIndicator.stopAnimating()
        controlButton.title = "Stop"
        UIApplication.shared.endIgnoringInteractionEvents()
        let synth = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "Start Sweeping")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.6
        synth.speak(utterance)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case sensorFusionCharacteristicCBUUID:
            
            sensorManager.sensorFusionReading(from: characteristic, caneLength: caneLength)
            
        default:
            1==2
        }
    }
    
}

extension MusicViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        let knownBeacons = beacons.filter{ $0.proximity != CLProximity.unknown }
        print("known beacons", knownBeacons)
        
        var newBeacons:[String] = []
        
        
        for each in knownBeacons {
            let tempstr = String(each.minor as! Int)
            if knownBeaconMinorsStrings.contains(tempstr) {
                break
            } else {
                newBeacons.append(tempstr)
                
            }
        }
        print(knownBeaconMinorsStrings)
        
        
        if newBeacons.count > 0 {
            
            for each in newBeacons {
                if let view = addViewController(atOffset: offset, dataForVC: each as AnyObject) {
                    viewsBeacons.append(view)
                    offset -= 25
                }
            }
            
        }
        
        for each in newBeacons {
            knownBeaconMinorsStrings.append(each)
            
        }
        
        
    }
}
