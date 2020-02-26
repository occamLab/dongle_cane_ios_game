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

/**
  You can't adjust the multiplier for a constraint so this reloads the constraint
*/
extension NSLayoutConstraint {
    func constraintWithMultiplier(_ multiplier: CGFloat) -> NSLayoutConstraint {
        return NSLayoutConstraint(item: self.firstItem, attribute: self.firstAttribute, relatedBy: self.relation, toItem: self.secondItem, attribute: self.secondAttribute, multiplier: multiplier, constant: self.constant)
    }
}
/**
  Sound View Controller
  `DUPLICATED` means this also appears on the Music View Controller
*/
class SoundViewController: UIViewController, UICollisionBehaviorDelegate {
    let overflowSize = Float(0.2)
    let underflowSize = Float(0.6)
    let validZoneSize =  Float(0.2)
    let synth = AVSpeechSynthesizer()

    ///Declare db to load options `DUPLICATED`
    let dbInterface = DBInterface.shared
    ///`DUPLICATED`
    let sensorManager = SensorManager()

    ///Helpful dictionary to find code from beep string
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
    ///`DUPLICATED`
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var playerName: UILabel!
    @IBOutlet weak var controlButton: UIBarButtonItem!
    ///`DUPLICATED` Progress bar

    @IBOutlet weak var stackViewBar: UIStackView!
    @IBOutlet weak var progressBarUI: UIProgressView!
    @IBOutlet weak var progressBarSize: NSLayoutConstraint!
    ///`DUPLICATED` Over the range
    @IBOutlet weak var progressBarOverflowUI: UIProgressView!
    @IBOutlet weak var progressBarOverflowSize: NSLayoutConstraint!
    ///`DUPLICATED` Under the range
    @IBOutlet weak var progressBarUnderflow: UIProgressView!
    @IBOutlet weak var progressBarUnderflowSize: NSLayoutConstraint!

    var isRecordingAudio = false
    
    
    @objc func handleChangeInAudioRecording(notification: NSNotification) {
        if let audioRecordingNewStatus = notification.object as? Bool {
            isRecordingAudio = audioRecordingNewStatus
            // nothing to do additionally right now
        }
    }

    /**
    `DUPLICATED`
    Calculate how full each progress bar should be:
    The progress bars are:
    The one that shows how far under the range they are
    The one that shows where in the range
    The one that shows how far over the range they are

    - Parameter notification: contains the current progress
    */
    @objc func updateProgress(notification: NSNotification){
        let currSweepRange = notification.object as! Float
        let sweepPercent = currSweepRange/sweepRange
        if( sweepPercent <= (1-percentTolerance!)){
            progressBarUnderflow.progress = sweepPercent/(1-percentTolerance!)
            progressBarUI.progress = 0
            progressBarOverflowUI.progress = 0
        } else if(sweepPercent <= (1+percentTolerance!)){
            progressBarUnderflow.progress = 1
            progressBarUI.progress = (sweepPercent - (1-percentTolerance!))/(2*percentTolerance!)
            progressBarOverflowUI.progress = 0
        } else{
            progressBarUnderflow.progress = 1.0
            progressBarUI.progress = 1.0
            let overflow_percent = (sweepPercent - 1 - percentTolerance!)/overflowSize

            if overflow_percent < 1{
                progressBarOverflowUI.progress = overflow_percent
            } else {
                progressBarOverflowUI.progress = 1
            }
        }
    }
    
    /**
       `DUPLICATED`
       Calculate the size of each progress bar on the screen:
       The progress bars are:
       The one that shows how far under the range they are
       The one that shows where in the range
       The one that shows how far over the range they are
       */
       func updateProgressView(){
           percentTolerance = sweepTolerance/sweepRange
           let totalSize:Float = underflowSize + overflowSize + validZoneSize
           let overflowSizeRel = overflowSize / totalSize

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
    ///Defintions for beacons `DUPLICATED`
    let locationManager = CLLocationManager()
    let region = CLBeaconRegion(proximityUUID: NSUUID(uuidString: "8492E75F-4FD6-469D-B132-043FE94921D8")! as UUID, identifier: "Estimotes")
    // 8492E75F-4FD6-469D-B132-043FE94921D8
    // B9407F30-F5F8-466E-AFF9-25556B57FE6D

    let beacons = ["Blue", "Purple", "Rose", "White"]

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
    ///Declare variables that are loaded from profile `DUPLICATED`
    var selectedProfile:String = "Default User"
    var selectedBeepStr: String = "Select Beep"
    var sweepRange: Float = 1.0
    var beepCount: Int = 10
    var sweepTolerance: Float = 20 //seems like a good value for a skiled cane user
    //Other important variable(s) not explicitly loaded from db
    var selectedSong:UInt64?
    var selectedBeepNoiseCode: Int?
    var percentTolerance: Float?
    /**
      `DUPLICATED`
      Load a user profile into global memory using the global `selectedProfile`
    */
    func loadProfile(){
        let user_row = self.dbInterface.getRow(u_name: selectedProfile)
        playerName.text = selectedProfile

        //Get beep noise
        selectedBeepStr = String(user_row![self.dbInterface.beep_noise])
        if(selectedBeepStr != "Select Beep"){
            selectedBeepNoiseCode = getBeepCode[selectedBeepStr]
        }

        //For the sliders
        sweepTolerance = Float(user_row![self.dbInterface.sweep_tolerance])
        beepCount = Int(user_row![self.dbInterface.beep_count])
        sweepRange = Float(user_row![self.dbInterface.sweep_width])
        sweepRangeLabel.text = String(Double(sweepRange).roundTo(places: 2)) + " inches"
        sweepRangeSliderUI.setValue(sweepRange, animated: false)
        sensorManager.caneLength = Float(user_row![self.dbInterface.cane_length])
    }


    @IBOutlet weak var sweepRangeLabel: UILabel!
    @IBOutlet weak var sweepRangeSliderUI: UISlider!
    /**
      `DUPLICATED`
      Allow the user to update the sweep range on the fly
      Will update the view of the progress bars
    */
    @IBAction func sweepRangeSlider(_ sender: UISlider) {
        let x = Double(sender.value).roundTo(places: 2)
        sweepRangeLabel.text = String(x) + " inches"
        sweepRange = sender.value
        updateProgressView()
    }



    var activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView()

    var startButtonPressed:Bool?
    var speakSweeps:Bool = true

    /**
      This is a function that gets activated whenever the start/stop button is pressed
      It will give feedback when it is looking for a connection and when it found one
      It should connect and init the audio player when started
      It should eset number beeps, stop the audio and disconnect when stopped
    */
    @IBAction func controlButton(_ sender: Any) {
        if controlButton.title == "Start" {
            if selectedBeepNoiseCode != nil || speakSweeps {


                activityIndicator.center = self.view.center
                activityIndicator.hidesWhenStopped = true
                activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
                view.addSubview(activityIndicator)

                activityIndicator.startAnimating()
                UIApplication.shared.beginIgnoringInteractionEvents()

                let utterance = AVSpeechUtterance(string: "Connecting")
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.6
                synth.speak(utterance)
                sensorManager.finishConnection(true) { () in
                    self.readyToSweep()
                }
                // temp true for sound mode
                startButtonPressed = true


            } else{
                createAlert(title: "Error", message: "You have not selected a beep noise.")

            }
        } else if controlButton.title == "Stop" {
            numSweeps = 0
            sensorManager.disconnectAndCleanup() { () in
                self.sensorManager.inSweepMode = false
                self.startButtonPressed = false

                let utterance = AVSpeechUtterance(string: "Disconnected")
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.6
                self.synth.speak(utterance)
                self.controlButton.title = "Start"
            }
        }
    }

    func createAlert (title:String, message:String) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))

        self.present(alert, animated: true, completion: nil)
    }
    //Definitions for sweeping
    var centralManager: CBCentralManager!
    var dongleSensorPeripheral: CBPeripheral!

    let sweep = Notification.Name(rawValue: sweepNotificationKey)
    let updateProgKey = Notification.Name(rawValue: updateProgressNotificationKey)

    var numSweeps:Int = 0

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

    /**
    When the sview is loaded function will (in order)
    1.Call the super view
    2. Create the side menu
    3. Choose which user profile is being used via default settings
    4. Load the profile preference
    5. Dynamically change the progress bars according to preferences
    6. Register functions for calls from other files (create observers)
    7. Handle Beacon stuff
    8. Center the text in the dynamic view
    */
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

        views.append(mvc.view)
        views.append(svc.view)
        for v in views {
            // make sure we comply with dark mode
            if #available(iOS 13.0, *) {
                v.backgroundColor = .systemBackground
            }
            viewContainer.addSubview(v)
        }
        viewContainer.bringSubview(toFront: views[0])
        //Make sure titles are centered and populated
        svc.beepNameLabel.text = selectedBeepStr
        svc.beepNameLabel.centerXAnchor.constraint(equalTo: viewContainer.centerXAnchor).isActive = true
        svc.beepNameLabel.centerYAnchor.constraint(equalTo: viewContainer.centerYAnchor).isActive = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleChangeInAudioRecording(notification:)), name: NSNotification.Name(rawValue: "handleChangeInAudioRecording"), object: nil)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sensorManager.inSweepMode = false
        print("Scanning for the dongle")
        sensorManager.scanForDevice()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // TODO: this screws stuff up on smaller phones, and possibly older OSes (since the popover is presented differently)
        // it can be called even when the Beacons are being configured
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        sensorManager.disconnectAndCleanup(postDisconnect: nil)
    }

    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(SoundViewController.processSweeps (notification:)), name: sweep, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SoundViewController.updateProgress(notification:)), name: updateProgKey, object: nil)
    }
    //Loads the navigation menu `DUPLICATED`
    func sideMenu() {

        if revealViewController() != nil {

            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            revealViewController().rearViewRevealWidth = 250

            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())

        }
    }
    
    func readyToSweep() {
        activityIndicator.stopAnimating()
        controlButton.title = "Stop"
        UIApplication.shared.endIgnoringInteractionEvents()
        let utterance = AVSpeechUtterance(string: "Start Sweeping")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.6
        synth.speak(utterance)
    }
    /**
      This function is called when the user switched cane movement directions.
    If the sweep is long enough it will beep or speak the count (depending on the mode)
    Parameter notification: Passed in container that has the length of the sweep
    */
    @objc func processSweeps(notification: NSNotification) {
        let sweepDistance = notification.object as! Float
        let is_valid_sweep = (sweepDistance > sweepRange - sweepTolerance) && (sweepDistance < sweepRange + sweepTolerance)
        print("sweepDistance", sweepDistance)
        if !isRecordingAudio, is_valid_sweep && startButtonPressed == true {

            numSweeps += 1

            if speakSweeps {
                //We are saying the number rather than playing a noise
                let string = String(numSweeps)
                let utterance = AVSpeechUtterance(string: string)
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.8
                synth.stopSpeaking(at: .immediate)
                synth.speak(utterance)
            } else {
                // beep mode
                AudioServicesPlaySystemSound(SystemSoundID(Float(selectedBeepNoiseCode!)))
            }
        }
    }
}

extension Double {
    func roundTo(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self*divisor).rounded() / divisor
    }
}
