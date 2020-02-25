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
let updateProgressNotificationKey = "cane.prog.notification"



extension UIViewController {
    /// call on a parent VC with desired child as param
    func add(_ child: UIViewController) {
        /// add the child to the parent
        addChildViewController(child)
        /// add the view of the child to the view of the parent
        view.addSubview(child.view)
        /// notify the child that it was moved to a parent
        child.didMove(toParentViewController: self)
    }
    
    /// call on a child VC
    func remove() {
        // Just to be safe, we check that this view controller
        // is actually added to a parent before removing it.
        guard parent != nil else {
            return
        }
        /// notify the child that it’s about to be removed
        willMove(toParentViewController: nil)
        /// remove the child’s view from the parent’s
        view.removeFromSuperview()
        /// remove the child from its parent
        removeFromParentViewController()
    }
}


/**
  Music View Controller
  `DUPLICATED` means this also appears on the Sound View Controller
*/
class MusicViewController: UIViewController, UICollisionBehaviorDelegate {
    let overflowSize = Float(0.2)
    let underflowSize = Float(0.6)
    let validZoneSize =  Float(0.2)
    
    @IBOutlet weak var currentSongButton: UIButton!
    @IBAction func currentSongButtonPressed(_ sender: Any) {
        UIApplication.shared.open(URL(string: "music://")!)
    }
    let mp = MPMusicPlayerController.systemMusicPlayer
    
    ///Declare db to load options `DUPLICATED`
    let dbInterface = DBInterface.shared
    ///`DUPLICATED`
    let sensorManager = SensorManager()

    ///`DUPLICATED`
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var playerName: UILabel!
    ///`DUPLICATED` Progress bar
    @IBOutlet weak var stackViewBar: UIStackView!
    @IBOutlet weak var progressBarUI: UIProgressView!
    @IBOutlet weak var progressBarSize: NSLayoutConstraint!
    ///`DUPLICATED`//Over the range
    @IBOutlet weak var progressBarOverflowUI: UIProgressView!
    @IBOutlet weak var progressBarOverflowSize: NSLayoutConstraint!
    ///`DUPLICATED`//Under the range
    @IBOutlet weak var progressBarUnderflow: UIProgressView!
    @IBOutlet weak var progressBarUnderflowSize: NSLayoutConstraint!

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

    ///For Beacons `DUPLICATED`
    let synth = AVSpeechSynthesizer()

    var animator:UIDynamicAnimator!
    var gravity:UIGravityBehavior!
    var snap:UISnapBehavior!
    var previousTouchPoint:CGPoint!
    var viewDragging = false
    var viewPinned = false

    var offset:CGFloat = 100
    var isRecordingAudio = false

    ///Declare variables that are loaded from profile `DUPLICATED`
    var selectedProfile:String = "Default User"
    var selectedSongStr: String = "Select Music"
    var selectedBeepStr: String = "Select Beep"
    var sweepRange: Float = 1.0
    var beepCount: Int = 10
    var sweepTolerance: Float = 20
    //Other important variable(s) not explicitly loaded from db
    var selectedSong:[Int64]?
    var percentTolerance: Float?
    /**
      `DUPLICATED`
      Load a user profile into global memory using the global `selectedProfile`
    */
    func loadProfile(){
        let user_row = self.dbInterface.getRow(u_name: selectedProfile)
        playerName.text = selectedProfile
        //Change beep noise
        selectedBeepStr = String(user_row![self.dbInterface.beep_noise])

        //Change Music Title
        if user_row![self.dbInterface.music] != "Select Music" {
            var myPlaylist = [MPMediaItem]()
            selectedSong = user_row![self.dbInterface.music_id].split(separator: ",").compactMap({Int64(String($0))})
            for songPersistentId in selectedSong! {
                let id = MPMediaPropertyPredicate(value: songPersistentId, forProperty: MPMediaItemPropertyPersistentID)
                let query = MPMediaQuery(filterPredicates: [id])
                if let song = query.items?.first {
                    myPlaylist.append(song)
                }
            }
            mp.setQueue(with: MPMediaItemCollection(items: myPlaylist))
            mp.repeatMode = .all
            mp.prepareToPlay()
            currentSongButton.isEnabled = true
            currentSongButton.setTitle(user_row![self.dbInterface.music], for: .normal)
        }else{
            currentSongButton.isEnabled = false
            currentSongButton.setTitle("Please select song on manage profiles screen", for: .normal)
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

    func readyToSweep() {
        activityIndicator.stopAnimating()
        controlButton.title = "Stop"
        UIApplication.shared.endIgnoringInteractionEvents()
        let synth = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "Start Sweeping")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.6
        synth.speak(utterance)
    }
    
    var activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView()
    //To start the session
    @IBOutlet weak var controlButton: UIBarButtonItem!
    var startButtonPressed:Bool? = false
    /**
      This is a function that gets activated whenever the start/stop button is pressed
      It will give feedback when it is looking for a connection and when it found one
      It should connect and init the audio player when started
      It should stop the audio and disconnect when stopped
    */
    @IBAction func controlButton(_ sender: Any) {

        if controlButton.title == "Start" {
            if selectedSong != nil {
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
                startButtonPressed = true // music mode has started
            } else {
                createAlert(title: "Error", message: "Please select song")
            }
        } else if controlButton.title == "Stop" {
            sensorManager.disconnectAndCleanup()
             { () in
                self.sensorManager.inSweepMode = false
                self.startButtonPressed = false
                self.mp.stop()
                // queue it up for next time
                self.mp.prepareToPlay()
                // TODO: change the playback to the default once it is done speaking?
                let utterance = AVSpeechUtterance(string: "Disconnected")
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.6
                self.synth.speak(utterance)
                self.controlButton.title = "Start"
            }
        }

    }
    //Start beacon code
    func createAlert (title:String, message:String) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))

        self.present(alert, animated: true, completion: nil)
    }
    //Variable Declaration
    var centralManager: CBCentralManager!
    var dongleSensorPeripheral: CBPeripheral!

    let sweep = Notification.Name(rawValue: sweepNotificationKey)
    let updateProgKey = Notification.Name(rawValue: updateProgressNotificationKey)

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    /**
    When the sview is loaded function will (in order)
    1.Call the super view
    2. Create the side menu
    3. Choose which user profile is being used via default settings
    4. Load the profile preference
    5. Dynamically change the progress bars according to preferences
    6. Register functions for calls from other files (create observers)
    7. Handle Beacon stuff
    */
    override func viewDidLoad() {
        super.viewDidLoad()

        sideMenu()
        //The new method should only use User defaults to know what the current profile is
        if (UserDefaults.standard.string(forKey: "currentProfile") == nil){
            UserDefaults.standard.set("Default User", forKey: "currentProfile")
        }
        selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        loadProfile()
        updateProgressView()
        createObservers()
        animator = UIDynamicAnimator(referenceView: self.view)
        gravity = UIGravityBehavior()

        animator.addBehavior(gravity)
        gravity.magnitude = 4
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleChangeInAudioRecording(notification:)), name: NSNotification.Name(rawValue: "handleChangeInAudioRecording"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.nowPlayingItemChanged(notification:)), name: NSNotification.Name.MPMusicPlayerControllerNowPlayingItemDidChange, object: nil)
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [.duckOthers,.interruptSpokenAudioAndMixWithOthers])
        mp.beginGeneratingPlaybackNotifications()
    }
    
    @objc func handleChangeInAudioRecording(notification: NSNotification) {
        if let audioRecordingNewStatus = notification.object as? Bool {
            isRecordingAudio = audioRecordingNewStatus
            if isRecordingAudio {
                // stop the music!!
                stopPlaying()
            }
        }
    }
    
    @objc func nowPlayingItemChanged(notification: NSNotification) {
        currentSongButton.setTitle(mp.nowPlayingItem?.title, for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sensorManager.inSweepMode = false
        print("Scanning for the dongle")
        sensorManager.scanForDevice()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        sensorManager.disconnectAndCleanup(postDisconnect: nil)
    }

    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(MusicViewController.processSweeps (notification:)), name: sweep, object: nil)
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

    var sweepTime:Float = 2.0

    var playing = -1
    var shouldPlay = -1

    var stopMusicTimer:Timer?
    /**
      This function is called when the user switched cane movement directions.
      If the sweep is long enough it will start or continue the music, otherwise
      it will stop the music
      Parameter notification: Passed in container that has the length of the sweep
    */
    @objc func processSweeps(notification: NSNotification) {

        if (!startButtonPressed!){ return}
        let sweepDistance = notification.object as! Float
        let is_valid_sweep = (sweepDistance > sweepRange - sweepTolerance) && (sweepDistance < sweepRange + sweepTolerance)
        // if we've turned around and we want to play music
        if is_valid_sweep && !isRecordingAudio {
            // we should play music
            shouldPlay = 1
            print("SweepRange: ", sweepRange)

            // todo: why is this not enabled? create a new timer in case a sweep takes too long?
            stopMusicTimer?.invalidate()
            stopMusicTimer = Timer.scheduledTimer(timeInterval: TimeInterval(2), target: self, selector: #selector(stopPlaying), userInfo: nil, repeats: false)
            // music has stopped but we want to restart it?
            if playing != shouldPlay {
                mp.play()
                playing = 1
            }
        } else{
        // stop music

            stopPlaying()
        }
    }

    /// Stops music from playing if necessary
    @objc func stopPlaying() {
        shouldPlay = -1
        if playing >= 0 {
            mp.pause()
            playing = -1
        }
    }
}
