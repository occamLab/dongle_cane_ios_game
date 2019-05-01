//
//  SoundViewController.swift
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

extension NSLayoutConstraint {
    func constraintWithMultiplier(_ multiplier: CGFloat) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: self.firstItem, attribute: self.firstAttribute, relatedBy: self.relation, toItem: self.secondItem, attribute: self.secondAttribute, multiplier: multiplier, constant: self.constant)
    }
}

class SoundViewController: UIViewController, UICollisionBehaviorDelegate {
    //Declare db to load options
    let dbInterface = DBInterface()
    let sensorManager = SensorManager()
    
    //Helpful dictionary to find code from beep string
    var getBeepCode = ["Begin": 1110,
                            "Begin Record": 1113,
                            "End Record": 1114,
                            "Clypso": 1022,
                            "Choo Choo": 1023,
                            "Congestion": 1071,
                            "General Beep": 1052,
                            "Positive Beep": 1054,
                            "Negative Beep": 1053,
                            "Keytone": 1075,
                            "Received": 1013,
                            "Tink": 1103,
                            "Tock": 1104,
                            "Tiptoes": 1034,
                            "Tweet": 1016]
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var playerName: UILabel!
    @IBOutlet weak var controlButton: UIBarButtonItem!
    //Progress bar
    
    @IBOutlet weak var stackViewBar: UIStackView!
    @IBOutlet weak var progressBarUI: UIProgressView!
    @IBOutlet weak var progressBarSize: NSLayoutConstraint!
    //Over the range
    @IBOutlet weak var progressBarOverflowUI: UIProgressView!
    @IBOutlet weak var progressBarOverflowSize: NSLayoutConstraint!
    //Under the range
    @IBOutlet weak var progressBarUnderflow: UIProgressView!
    @IBOutlet weak var progressBarUnderflowSize: NSLayoutConstraint!
    
    
    @objc func updateProgress(notification: NSNotification){
        
        let currSweepRange = notification.object as! Float
        let sweepPercent = currSweepRange/sweepRange
        let overflowBarLength = (0.33-percentTolerance!)
        var progressAdjuster:Float = 0
        if overflowBarLength < 0{
            progressAdjuster = overflowBarLength
        }
        
        if( sweepPercent <= (1-percentTolerance!)){
            progressBarUnderflow.progress = sweepPercent/(1-percentTolerance!)
            progressBarUI.progress = 0
            progressBarOverflowUI.progress = 0
            
        }else if(sweepPercent <= (1+percentTolerance!)){
            progressBarUnderflow.progress = 1
            progressBarUI.progress = (sweepPercent - (1-percentTolerance!))/((2*percentTolerance!) + progressAdjuster)
            progressBarOverflowUI.progress = 0
            
        }else{
            progressBarUnderflow.progress = 1.0
            progressBarUI.progress = 1.0
            if (overflowBarLength <= 0){
                return
            }
            let overflow_percent = (sweepPercent - 1 - percentTolerance!)/overflowBarLength

            if overflow_percent < 1{
                progressBarOverflowUI.progress = overflow_percent
            }else{
                progressBarOverflowUI.progress = 1
            }
        }
    }
    
    func updateProgressView(){
        percentTolerance = sweepTolerance/sweepRange
        let totalSize:Float = 1.33
        let overflowSizeAbs:Float = (0.33-percentTolerance!)
        var progressAdjuster:Float = 0
        var overflowSizeRel = overflowSizeAbs / totalSize
        
        if overflowSizeAbs < 0{
            progressAdjuster = overflowSizeAbs
            overflowSizeRel = 0
        }
        let underflowSize = (1-percentTolerance!) / totalSize
        
        let validZoneSize = (2 * percentTolerance! + progressAdjuster)/totalSize
        print("\(underflowSize)")
        print(overflowSizeRel)
        print(validZoneSize)
       //----Update Values
        var newConstraint = progressBarUnderflowSize.constraintWithMultiplier(CGFloat(underflowSize))
        self.stackViewBar.removeConstraint(progressBarUnderflowSize)
        progressBarUnderflowSize = newConstraint
        self.stackViewBar.addConstraint(progressBarUnderflowSize)
        
        newConstraint = progressBarOverflowSize.constraintWithMultiplier(CGFloat(overflowSizeRel))
        self.stackViewBar.removeConstraint(progressBarOverflowSize)
        progressBarOverflowSize = newConstraint
        self.stackViewBar.addConstraint(progressBarOverflowSize)
        
        newConstraint = progressBarSize.constraintWithMultiplier(CGFloat(validZoneSize))
        self.stackViewBar.removeConstraint(progressBarSize)
        progressBarSize = newConstraint
        self.stackViewBar.addConstraint(progressBarSize)
        
        self.stackViewBar.layoutIfNeeded()
        
    }
    
    //---------------------------
    //Defintions for beacons
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
    //----------------------------
    //Declare variables that are loaded from profile
    var selectedProfile:String = "Default User"
    var selectedSongStr: String = "Select Music"
    var selectedBeepStr: String = "Select Beep"
    var sweepRange: Float = 1.0
    var caneLength: Float = 1.0
    var beepCount: Int = 10
    var sweepTolerance: Float = 20 //seems like a good value for a skiled cane user
    //Other important variable(s) not explicitly loaded from db
    var selectedSong:URL?
    var selectedBeepNoiseCode: Int?
    var percentTolerance: Float?
    
    func loadProfile(){
        let user_row = self.dbInterface.getRow(u_name: selectedProfile)
        playerName.text = selectedProfile
        
        //Get Music Title
        selectedSongStr = String(user_row![self.dbInterface.music])
        
        if(selectedSongStr != "Select Music"){
            selectedSong = URL.init(string: user_row![self.dbInterface.music_url])
        }
        //Get beep noise
        selectedBeepStr = String(user_row![self.dbInterface.beep_noise])
        if(selectedBeepStr != "Select Beep"){
            selectedBeepNoiseCode = getBeepCode[selectedBeepStr]
        }
        
        //For the sliders
        sweepTolerance = Float(user_row![self.dbInterface.sweep_tolerance])
        beepCount = Int(user_row![self.dbInterface.beep_count])
        sweepRange = Float(user_row![self.dbInterface.sweep_width])
        sweepRangeLabel.text = String(sweepRange)
        sweepRangeSliderUI.setValue(sweepRange, animated: false)
        
        caneLength = Float(user_row![self.dbInterface.cane_length])
        
    }
    
    
    @IBOutlet weak var sweepRangeLabel: UILabel!
    @IBOutlet weak var sweepRangeSliderUI: UISlider!
    @IBAction func sweepRangeSlider(_ sender: UISlider) {
        let x = Double(sender.value).roundTo(places: 2)
        sweepRangeLabel.text = String(x)
        sweepRange = sender.value
        updateProgressView()
    }
    
    
    
    var activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView()
    
    var startButtonPressed:Bool?
    var speakSweeps:Bool = true
    
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
                
                // temp true for sound mode
                startButtonPressed = true
                
                
            } else {
                createAlert(title: "Error", message: "Not all required fields are complete")
                
            }
        } else if controlButton.title == "Stop" {
            numSweeps = 0
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
            
        }
  
        
    }
    
    
    
    func createAlert (title:String, message:String) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    var centralManager: CBCentralManager!
    var dongleSensorPeripheral: CBPeripheral!
    
    var audioPlayer: AVAudioPlayer?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    
    let sweep = Notification.Name(rawValue: sweepNotificationKey)
    let updateProgKey = Notification.Name(rawValue: updateProgressNotificationKey)
    var beginningMusic = true
    
    var startSweep = true
    var startDir:[Float] = []
    var anglePrev:Float = 0.0
    
    var numSweeps:Int = 0
    
    func populateRewards() -> ([Int: Bool]) {
        
        var reward: [Int: Bool] = [:]
        
        for num in [beepCount, 100, 250, 500, 1000]{
            reward[num] = true
        }
        return reward
    }
    
    lazy var rewardAt = populateRewards()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    
    @IBAction func segmentedControl(_ sender: UISegmentedControl) {
        self.viewContainer.bringSubview(toFront: views[sender.selectedSegmentIndex])
        if sender.selectedSegmentIndex == 1 {
            speakSweeps = false
        } else {
            speakSweeps = true
        }
    }
    
    @IBOutlet weak var viewContainer: UIView!
    var views: [UIView]!


    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        //Load the options from the database
        if (UserDefaults.standard.string(forKey: "currentProfile") == nil){
            UserDefaults.standard.set("Default User", forKey: "currentProfile")
        }
        selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        loadProfile()
        updateProgressView()
        numSweeps = 0
        createObservers()
        //-------------------
        //Inits for the beacon controllers
        locationManager.delegate = self
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startRangingBeacons(in: region)
        
        animator = UIDynamicAnimator(referenceView: self.view)
        gravity = UIGravityBehavior()
        
        animator.addBehavior(gravity)
        gravity.magnitude = 4
        //-----------------
        //We define a list of potential views for the center view container and put them in a list
        //We can then index in this list to bring the desired text to the front and display it
        views = [UIView]()
        let mvc = MusicSegmentViewController()
        let svc = BeepSegmentViewController()
        
//        mvc.songTitleLabel.center = self.viewContainer.center
//        svc.beepNameLabel.center = self.viewContainer.center
        views.append(mvc.view)
        views.append(svc.view)
        for v in views {
            viewContainer.addSubview(v)
        }
        viewContainer.bringSubview(toFront: views[0])
        //Make sure titles are centered and populated
        mvc.songTitleLabel.text = selectedSongStr
        mvc.songTitleLabel.centerXAnchor.constraint(equalTo: viewContainer.centerXAnchor).isActive = true
        mvc.songTitleLabel.centerYAnchor.constraint(equalTo: viewContainer.centerYAnchor).isActive = true
        svc.beepNameLabel.text = selectedBeepStr
        svc.beepNameLabel.centerXAnchor.constraint(equalTo: viewContainer.centerXAnchor).isActive = true
        svc.beepNameLabel.centerYAnchor.constraint(equalTo: viewContainer.centerYAnchor).isActive = true

        
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
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(SoundViewController.processSweeps (notification:)), name: sweep, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SoundViewController.updateProgress(notification:)), name: updateProgKey, object: nil)
    }


    
    func sideMenu() {
        
        if revealViewController() != nil {
            
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            revealViewController().rearViewRevealWidth = 250
            
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
            
        }
    }
    
    @objc func processSweeps(notification: NSNotification) {
        let sweepDistance = notification.object as! Float
        let is_valid_sweep = (sweepDistance > sweepRange - sweepTolerance) && (sweepDistance < sweepRange + sweepTolerance)

        if is_valid_sweep && startButtonPressed == true {
            
            numSweeps += 1
            print("SweepRange: ", sweepRange)
            
            if speakSweeps == true {
                //We are saying the number rather than playing a noise
                print("im speaking")
                let string = String(numSweeps)
                let synth = AVSpeechSynthesizer()
                let utterance = AVSpeechUtterance(string: string)
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.8
                synth.speak(utterance)
            } else {
                // beep mode
                AudioServicesPlaySystemSound(SystemSoundID(Float(selectedBeepNoiseCode!)))
            }
            
            
            if rewardAt[numSweeps] != nil && rewardAt[numSweeps]! {
                if beginningMusic == true {
                    if selectedSong != nil {
                        
                        do {
                            audioPlayer = try AVAudioPlayer(contentsOf: selectedSong! as URL)
                            
                        } catch {
                            print("oh no")
                        }
                    } else {
                        createAlert(title: "Error", message: "Could not find song address on device. Make sure it is on your device, not in you iClound library")
                    }
                    
                    beginningMusic = false
                    
                }
                audioPlayer?.play()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { // change to to desired number of seconds
                    // Your code with delay
                    self.audioPlayer?.pause()
                }
            }
        }
    }
    


}

extension SoundViewController: CBCentralManagerDelegate {
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
            centralManager.scanForPeripherals(withServices: [dongleSensorCBUUID])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        dongleSensorPeripheral = peripheral
        dongleSensorPeripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(dongleSensorPeripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        dongleSensorPeripheral.discoverServices(nil)
    }
}

extension Double {
    func roundTo(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self*divisor).rounded() / divisor
    }
}

extension SoundViewController: CBPeripheralDelegate {
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

extension SoundViewController: CLLocationManagerDelegate {
    
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
