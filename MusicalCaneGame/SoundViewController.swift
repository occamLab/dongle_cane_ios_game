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
    let synth = AVSpeechSynthesizer()

    ///Declare db to load options `DUPLICATED`
    let dbInterface = DBInterface.shared
    ///Helpful dictionary to find path from beep string
    static var getBeepPath = ["Begin": "/System/Library/Audio/UISounds/jbl_begin.caf",
                            "Begin Record": "/System/Library/Audio/UISounds/begin_record.caf",
                            "End Record": "/System/Library/Audio/UISounds/end_record.caf",
                            "Calypso": "/System/Library/Audio/UISounds/New/Calypso.caf",
                            "Choo Choo": "/System/Library/Audio/UISounds/New/Choo_Choo.caf",
                            "Congestion": "/System/Library/Audio/UISounds/ct-congestion.caf",
                            "General Beep": "/System/Library/Audio/UISounds/SIMToolkitGeneralBeep.caf",
                            "Positive Beep": "/System/Library/Audio/UISounds/SIMToolkitPositiveACK.caf",
                            "Negative Beep": "/System/Library/Audio/UISounds/SIMToolkitNegativeACK.caf",
                            "Keytone": "/System/Library/Audio/UISounds/ct-keytone2.caf",
                            "Received": "/System/Library/Audio/UISounds/sms-received5.caf",
                            "Tink": "/System/Library/Audio/UISounds/Tink.caf",
                            "Tock": "/System/Library/Audio/UISounds/Tock.caf",
                            "Tiptoes": "/System/Library/Audio/UISounds/New/Tiptoes.caf",
                            "Tweet": "/System/Library/Audio/UISounds/tweet_sent.caf"]
    
    ///`DUPLICATED`
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var playerName: UILabel!
    @IBOutlet weak var controlButton: UIBarButtonItem!
    ///`DUPLICATED` Progress bar
    
    var isRecordingAudio = false
    
    
    @objc func handleChangeInAudioRecording(notification: NSNotification) {
        if let audioRecordingNewStatus = notification.object as? Bool {
            isRecordingAudio = audioRecordingNewStatus
            // nothing to do additionally right now
        }
    }

    var animator:UIDynamicAnimator!
    var gravity:UIGravityBehavior!
    var snap:UISnapBehavior!
    var previousTouchPoint:CGPoint!
    var viewDragging = false
    var viewPinned = false

    var offset:CGFloat = 100
    var knownBeaconMinorsStrings:[String] = []
    //----------------------------
    ///Declare variables that are loaded from profile
    var selectedProfile:String = "Default User"
    var selectedBeepStr: String = "Select Beep"
    var isWheelchairUser: Bool = false

    //Other important variable(s) not explicitly loaded from db
    var selectedBeepNoisePath: String?
    var beepPlayer: AVAudioPlayer!

    /**
      Load a user profile into global memory using the global `selectedProfile`
    */
    func loadProfile(){
        let user_row = self.dbInterface.getRow(u_name: selectedProfile)
        playerName.text = selectedProfile
        isWheelchairUser = user_row![dbInterface.wheelchair_user]
        //Get beep noise
        selectedBeepStr = String(user_row![self.dbInterface.beep_noise])
        if(selectedBeepStr != "Select Beep"){
            selectedBeepNoisePath = SoundViewController.getBeepPath[selectedBeepStr]
            beepPlayer = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: selectedBeepNoisePath!))
            beepPlayer.prepareToPlay()
        }
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
            if selectedBeepNoisePath != nil || speakSweeps {
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
                NotificationCenter.default.post(name: Notification.Name(rawValue: connectionStatusChangeRequested), object: true)
                // temp true for sound mode
                startButtonPressed = true
            } else{
                createAlert(title: "Error", message: "You have not selected a beep noise.")
            }
        } else if controlButton.title == "Stop" {
            numSweeps = 0
            NotificationCenter.default.post(name: Notification.Name(rawValue: connectionStatusChangeRequested), object: false)
        }
    }

    func createAlert (title:String, message:String) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))

        self.present(alert, animated: true, completion: nil)
    }

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
        numSweeps = 0

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
        createObservers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // TODO: this screws stuff up on smaller phones, and possibly older OSes (since the popover is presented differently)
        // it can be called even when the Beacons are being configured
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(SoundViewController.processSweeps (notification:)), name: sweep, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SoundViewController.processConnectionStatusChangeCompleted(notification:)), name: NSNotification.Name(rawValue: connectionStatusChangeCompleted), object: nil)
    }

    
    @objc func processConnectionStatusChangeCompleted(notification: NSNotification) {
        let connected = notification.object as! Bool
        if connected {
            readyToSweep()
        } else {
            startButtonPressed = false

            let utterance = AVSpeechUtterance(string: "Disconnected")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.6
            synth.speak(utterance)
            controlButton.title = "Start"
        }
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
        let utterance = AVSpeechUtterance(string: "Start " + (isWheelchairUser ? "Moving" : "Sweeping"))
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
        let is_valid_sweep = notification.object as! Bool
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
                beepPlayer.play()
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
