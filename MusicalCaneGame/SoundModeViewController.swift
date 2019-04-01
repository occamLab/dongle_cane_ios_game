//
//  SoundModeViewController.swift
//  MusicalCaneGame
//
//  Created by scope on 7/30/18.
//  Copyright © 2018 occamlab. All rights reserved.
//


import UIKit
import CoreBluetooth
import AVFoundation
import MediaPlayer


class SoundModeViewController: UIViewController {

    
    
    // reward music
    @IBOutlet weak var rewardTrackLabel: UILabel!
    var selectedRewardTrack: String?
    
    @IBOutlet weak var rewardTrackPicker: UIButton!
    @IBAction func chooseRewardTrack(_ sender: Any) {
        let myMediaPickerVC = MPMediaPickerController.self(mediaTypes: MPMediaType.music)
        myMediaPickerVC.allowsPickingMultipleItems = false
        //        myMediaPickerVC.popoverPresentationController?.sourceView = sender as! UIView
        myMediaPickerVC.delegate = self
        self.present(myMediaPickerVC, animated: true, completion: nil)
    }
    
    var selectedSong: MPMediaItemCollection?
    
    // Beep noise
    @IBOutlet weak var beepNoiseLabel: UILabel!


    // Count Mode Toggle Switch
    @IBOutlet weak var countModeToggle: UISwitch!
    @IBAction func changeCountMode(_ sender: Any) {
        countSweeps = countModeToggle.isOn
        if countSweeps == false {
            createAlert(title: "Reminder", message: """
                                                    Beep Mode uses the phone's system sounds. Make sure that your ringer volume (different than
                                                    than sound volume) is turned all the way up so that you can hear the music.
                                                    """)
            beepNoiseLabel.isEnabled = true
            beepNoiseTextField.isEnabled = true
        } else {
            beepNoiseLabel.isEnabled = false
            beepNoiseTextField.isEnabled = false
        }
        
        if startButton.isEnabled == false {
            selectedBeepNoise = beepNoises[0]
            selectedBeepNoiseCode = beepNoiseCodes[0]
            beepNoiseTextField.text = selectedBeepNoise

        }
    }
    
    @IBOutlet weak var beepNoiseTextField: UITextField!
    let beepNoises = ["Begin", "Begin Record", "End Record", "Clypso", "Choo Choo", "Congestion", "General Beep", "Positive Beep", "Negative Beep",
                      "Keytone", "Received", "Tink", "Tock", "Tiptoes", "Tweet"]
    let beepNoiseCodes = [1110, 1113, 1114, 1022, 1023, 1071, 1052, 1054, 1053, 1075, 1013, 1103, 1104, 1034, 1016]
    var selectedBeepNoise: String?
    var selectedBeepNoiseCode: Int?
    
    
    // sweep range
    var sweepRange: Float = 1.0
    @IBOutlet weak var sweepRangeLabel: UILabel!
    @IBAction func sweepRangeSlider(_ sender: UISlider) {
        sweepRangeLabel.text = String(sender.value)
        sweepRange = sender.value
    }

    
    // connect button
    var activityIndicator:UIActivityIndicatorView = UIActivityIndicatorView()
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!

    // distinquish between sound and music mode, when not used, counts on music mode
    var temp:Bool?
    @IBAction func startButton(_ sender: UIButton) {
        if selectedSong != nil {
            if countModeToggle.isOn == true || (countModeToggle.isOn == false && selectedBeepNoise != nil) {
                // activity indicator to show the user it is trying to connect
                activityIndicator.center = self.view.center
                activityIndicator.hidesWhenStopped = true
                activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
                view.addSubview(activityIndicator)
                
                activityIndicator.startAnimating()
                UIApplication.shared.beginIgnoringInteractionEvents()
                
                // text to speech
                let synth = AVSpeechSynthesizer()
                let utterance = AVSpeechUtterance(string: "Connecting")
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = 0.6
                synth.speak(utterance)
                
                // searches for dongle
                centralManager = CBCentralManager(delegate: self, queue: nil)
                
                // true for sound mode
                temp = true
                startButton.isEnabled = false
                stopButton.isEnabled = true
            }
        
        } else {
            // pop up alert if the reward music field is not completed. Needs a track to run
            createAlert(title: "Error", message: "Not all required fields are complete")
        }
    }
    
    @IBAction func stopButton(_ sender: UIButton) {
        // disconnects drom the dongle
        centralManager.cancelPeripheralConnection(dongleSensorPeripheral)
        temp = nil
        audioPlayer?.stop()
        numSweeps = 0
        
        // text to speech
        let synth = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "Disconnected")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.6
        synth.speak(utterance)
        
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }
    
    // Visulizing Sweep
    //    @IBOutlet weak var sweepProgress: UIProgressView!
    
    
    // creating alert
    func createAlert (title:String, message:String) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    var centralManager: CBCentralManager!
    var dongleSensorPeripheral: CBPeripheral!
    
    var audioPlayer: AVAudioPlayer?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    
    var beginningMusic = true
    
    let sweep = Notification.Name(rawValue: sweepNotificationKey)
    
    var startSweep = true
    var startDir:[Float] = []
    var anglePrev:Float = 0.0
    let caneLength:Float = 1.1684

    var countSweeps = true
    var numSweeps:Int = 0
    
    func populateRewards() -> ([Int: Bool]) {
        
        var reward: [Int: Bool] = [:]
        
        for num in [10, 25, 50, 100, 250, 500, 1000]{
            reward[num] = true
        }
        return reward
    }
    
    lazy var rewardAt = populateRewards()
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        createObservers()
        createBeepNoisePicker(countNoisePicker: countBeepPicker)
        createToolbar()
    }
    
    let countBeepPicker = UIPickerView()
    func createBeepNoisePicker(countNoisePicker: UIPickerView) {
        countNoisePicker.delegate = self
        beepNoiseTextField.inputView = countNoisePicker
    }

    func createToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(SoundModeViewController.dismissKeyboard))

        toolbar.setItems([doneButton], animated: false)
        toolbar.isUserInteractionEnabled = true

        beepNoiseTextField.inputAccessoryView = toolbar
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(SoundModeViewController.processSweeps (notification:)), name: sweep, object: nil)
    }
    
    
    @objc func processSweeps(notification: NSNotification) {
        
        let sweepDistance = notification.object as! Float
        
        if sweepDistance > sweepRange && temp == true {
            numSweeps += 1
            print("SweepRange: ", sweepRange)
            
            if countSweeps == true {
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
            
            let temp = rewardAt[numSweeps]
            if temp != nil && rewardAt[numSweeps] == true {
                if beginningMusic == true {
                    if selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL) != nil {
                
                        do {
                            audioPlayer = try AVAudioPlayer(contentsOf: selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL) as! URL)
                            
                        } catch {
                            print("oh no")
                        }
                    } else {
                        createAlert(title: "Error", message: "Could not find song address on device. Make sure it is on your device, not in you iClound library")
                    }
                    
                    beginningMusic = false
                
                }
                audioPlayer?.play()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { // change 2 to desired number of seconds
                    // Your code with delay
                    self.audioPlayer?.pause()
                }
            }
        }
    }
}

extension SoundModeViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == countBeepPicker {
            return beepNoises.count
        }
        return 0
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == countBeepPicker {
            return beepNoises[row]
        }
        return ""
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == countBeepPicker {
            selectedBeepNoiseCode = beepNoiseCodes[row]
            selectedBeepNoise = beepNoises[row]
            beepNoiseTextField.text = selectedBeepNoise
        }
    }
}

extension SoundModeViewController: CBCentralManagerDelegate {
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

extension SoundModeViewController: MPMediaPickerControllerDelegate {
    
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        myMediaPlayer.setQueue(with: mediaItemCollection)
        selectedSong = mediaItemCollection
        beginningMusic = true
        rewardTrackPicker.setTitle(selectedSong?.items[0].title, for: .normal)
        mediaPicker.dismiss(animated: true, completion: nil)

    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
    
    
}

extension SoundModeViewController: CBPeripheralDelegate {
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
            
            sensorFusionReading(from: characteristic)
            
        default:
            1==2
            
        }
    }
    
    private func sensorFusionReading(from characteristic: CBCharacteristic) {
        guard let characteristicData = characteristic.value else { return }
        let byteArray = [UInt8](characteristicData)
        let data = Data(bytes: byteArray[3...])
        
        let array = data.withUnsafeBytes {
            [Int16](UnsafeBufferPointer(start: $0, count: 4))
        }
        
        // get quaternion vales from the dongle
        let w = Float(array[0]) / Float(Int16.max)
        let x = Float(array[1]) / Float(Int16.max)
        let y = Float(array[2]) / Float(Int16.max)
        let z = Float(array[3]) / Float(Int16.max)
        
        
        // Rotation Matrix
        // math from euclideanspace
        // for normalization
        let invs = 1 / (x*x + y*y + z*z + w*w)
        
        // x and y projected on z axis from matrix
        let m02 = 2.0 * (x*z + y*w) * invs
        let m12 = 2.0 * (y*z - x*w) * invs
        
        // normaized vector values multiplied by cane length
        // to estimate tip of cane
        let xPos = m02 * caneLength
        let yPos = m12 * caneLength
        
        if xPos.isNaN || yPos.isNaN || (xPos == 0 && yPos == 0) {
            return
        }
        
        let lengthOnZAxiz = sqrt((xPos * xPos) + (yPos * yPos))
        
        if lengthOnZAxiz > 0.6 {
            
            // normalizing
            var direction = [xPos, yPos]
            let magnitude = lengthOnZAxiz
            direction = direction.map { $0 / magnitude }
            
            // sets frist position as direction as a reference point
            if startSweep == true {
                startDir = direction
                startSweep = false
            }
            
            // using dot product to find angle between starting vector and current direction
            // varified
            let angleFromStarting = acos(direction[0] * startDir[0] + direction[1] * startDir[1])
            
            // change in angle
            let deltaAngle = angleFromStarting - anglePrev
            
            // change in angle from raidans to degrees
            let deltaAngleDeg = deltaAngle * 57.2958
            let sweepDistance = caneLength * sin(angleFromStarting / 2) * 2
//            sweepProgress.setProgress(sweepDistance/sweepRange, animated: false)
            
            if deltaAngleDeg > 1.0 || deltaAngleDeg < -1.0 {
                
                if deltaAngle < 0 {
                    
                    // changed
                    
                    let name = Notification.Name(rawValue: sweepNotificationKey)
                    NotificationCenter.default.post(name: name, object: sweepDistance)
                    
                    startDir = direction
                    anglePrev = 0.0
                    return
                }
            }
            anglePrev = angleFromStarting
        }
        return
    }
}
