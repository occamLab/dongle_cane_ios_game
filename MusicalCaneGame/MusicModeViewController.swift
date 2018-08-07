//
//  MusicModeViewController.swift
//  MusicalCaneGame
//
//  Created by scope on 7/20/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation
import MediaPlayer

let dongleSensorCBUUID = CBUUID(string: "2ea7")
let sensorFusionCharacteristicCBUUID = CBUUID(string: "2ea78970-7d44-44bb-b097-26183f402407")
let sweepNotificationKey = "cane.sweep.notification"

class MusicModeViewController: UIViewController {

    @IBOutlet weak var musicTrackPicker: UIButton!
    
    @IBAction func chooseMusicTrack(_ sender: Any) {
        let myMediaPickerVC = MPMediaPickerController.self(mediaTypes: MPMediaType.music)
        myMediaPickerVC.allowsPickingMultipleItems = false
        //        myMediaPickerVC.popoverPresentationController?.sourceView = sender as! UIView
        myMediaPickerVC.delegate = self
        self.present(myMediaPickerVC, animated: true, completion: nil)
    }
    
    var selectedSong: MPMediaItemCollection?
    
    // sweep range slider
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
    
    var temp:Bool?
    @IBAction func startButton(_ sender: UIButton) {
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
            temp = false
            startButton.isEnabled = false
            stopButton.isEnabled = true
            musicTrackPicker.isEnabled = false
        } else {
            createAlert(title: "Error", message: "Not all required fields are complete")

        }
    }
        

    @IBAction func stopButton(_ sender: UIButton) {
        centralManager.cancelPeripheralConnection(dongleSensorPeripheral)
        //  forget when i reest temp? here, maybe i should make it nil instead? also, i should rename because I already have temp in this file
        temp = nil
        audioPlayer?.stop()
        
        // text to speech
        let synth = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "Disconnected")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.6
        synth.speak(utterance)
        
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }
    
    func createAlert (title:String, message:String) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))
        
        self.present(alert, animated: true, completion: nil)
    }
    

    // Visulizing Sweep
    // @IBOutlet weak var sweepProgress: UIProgressView!
    
    var centralManager: CBCentralManager!
    var dongleSensorPeripheral: CBPeripheral!
    
    var audioPlayer: AVAudioPlayer?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer


    let sweep = Notification.Name(rawValue: sweepNotificationKey)
 
    var startSweep = true
    var startDir:[Float] = []
    var anglePrev:Float = 0.0
    let caneLength:Float = 1.1684
    
    var beginningMusic = true
    var sweepTolerance:Float = 2.0
    
    var playing = -1
    var shouldPlay = -1

    var stopMusicTimer:Timer?
    var lastSweep = Date()
  
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        createObservers()
    }
   
    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(MusicModeViewController.processSweeps (notification:)), name: sweep, object: nil)
    }
    
    @objc func processSweeps(notification: NSNotification) {

        let sweepDistance = notification.object as! Float
        if sweepDistance > sweepRange && temp == false {
            shouldPlay = 1
            print("SweepRange: ", sweepRange)

            stopMusicTimer?.invalidate()
            stopMusicTimer = Timer.scheduledTimer(timeInterval: TimeInterval(sweepTolerance), target: self, selector: #selector(runCode), userInfo: nil, repeats: true)
            let now = Date()
            lastSweep = now
            if playing != shouldPlay && shouldPlay >= -1 {
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
                audioPlayer?.numberOfLoops = -1
                playing = shouldPlay
            }
        }
    }

    @objc func runCode() {
        shouldPlay = -1
        if playing >= 0 {
            audioPlayer?.pause()
            playing = -1
        }
    }
}

extension MusicModeViewController: CBCentralManagerDelegate {
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

extension MusicModeViewController: MPMediaPickerControllerDelegate {
    
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        myMediaPlayer.setQueue(with: mediaItemCollection)
        selectedSong = mediaItemCollection
        beginningMusic = true
        musicTrackPicker.setTitle(selectedSong?.items[0].title, for: .normal)
        mediaPicker.dismiss(animated: true, completion: nil)
        
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
}


extension MusicModeViewController: CBPeripheralDelegate {
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
