//
//  GameSettingsViewController.swift
//  MusicalCaneGame
//
//  Created by Anna Griffin on 10/5/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation
import MediaPlayer

class GameSettingsViewController: UIViewController {

    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    // Music Track Picker
    @IBOutlet weak var musicTrackPicker: UIButton!
    @IBOutlet weak var beepNoiseBox: UITextField!
    @IBOutlet weak var beepCountSlider: UISlider!
    @IBOutlet weak var beepCountLabel: UILabel!
    @IBOutlet weak var caneLengthSlider: UISlider!
    @IBOutlet weak var caneLengthLabel: UILabel!
    @IBOutlet weak var sweepRangeSlider: UISlider!
    @IBOutlet weak var sweepRangeLabel: UILabel!
    
    var selectedMusicTrack: String?
    @IBAction func chooseMusictrack(_ sender: Any) {
        let myMediaPickerVC = MPMediaPickerController.self(mediaTypes: MPMediaType.music)
        myMediaPickerVC.allowsPickingMultipleItems = false
        myMediaPickerVC.delegate = self
        self.present(myMediaPickerVC, animated: true, completion: nil)
        
        
    }
    
    
    @IBAction func beepCountChanged(_ sender: UISlider) {
        beepCountLabel.text = String(Int(sender.value))
    }
    
    var selectedSong: MPMediaItemCollection?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    
    // Beep noise picker
    @IBOutlet weak var beepNoiseTextField: UITextField!
    let beepNoises = ["Begin", "Begin Record", "End Record", "Clypso", "Choo Choo", "Congestion", "General Beep", "Positive Beep", "Negative Beep",
                      "Keytone", "Received", "Tink", "Tock", "Tiptoes", "Tweet"]
    let beepNoiseCodes = [1110, 1113, 1114, 1022, 1023, 1071, 1052, 1054, 1053, 1075, 1013, 1103, 1104, 1034, 1016]
    var selectedBeepNoise: String?
    var selectedBeepNoiseCode: Int?
    
    var temp: URL?
    var mySong: URL?


    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        createBeepNoisePicker(countNoisePicker: countBeepPicker)
        createToolbar()
        

    
//        let defaults = UserDefaults.standard
//        let mySong = defaults.object(forKey: UserDefaultsKeys.NSRUL.rawValue) as! Data
//        print(mySong ?? "hi")
        

        // Do any additional setup after loading the view.
    }
    
    let countBeepPicker = UIPickerView()
    func createBeepNoisePicker(countNoisePicker: UIPickerView) {
        countNoisePicker.delegate = self
        beepNoiseTextField.inputView = countNoisePicker
    }
    func createToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(SoundViewController.dismissKeyboard))
        
        toolbar.setItems([doneButton], animated: false)
        toolbar.isUserInteractionEnabled = true
        
        beepNoiseTextField.inputAccessoryView = toolbar
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {

            // set selected song button
        if let y = UserDefaults.standard.string(forKey: "mySongTitle") {
            musicTrackPicker.setTitle(y, for: .normal)
        }
            // set beep noise text field
        if let n = UserDefaults.standard.string(forKey: "myBeepNoise") {
            beepNoiseTextField.text = n
        }
 
    }
    

    
    func sideMenu() {
        
        if revealViewController() != nil {
            
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            revealViewController().rearViewRevealWidth = 250
            
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
            
        }
    }
}
    

extension GameSettingsViewController: MPMediaPickerControllerDelegate {
    
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        myMediaPlayer.setQueue(with: mediaItemCollection)
        selectedSong = mediaItemCollection
        temp = selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL) as? URL
        
        //Configuration.setUserProperty(forUser: <#T##String#>, key: <#T##String#>, value: <#T##String#>)
        
        // artist
        UserDefaults.standard.set(selectedSong?.items[0].albumArtist, forKey: "myArtist")
        // URL
        UserDefaults.standard.set(temp, forKey: "mySongURL")
        //Song title
        UserDefaults.standard.set(selectedSong?.items[0].title, forKey: "mySongTitle")
        
        musicTrackPicker.setTitle(selectedSong?.items[0].title, for: .normal)
        mediaPicker.dismiss(animated: true, completion: nil)
        
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }
   
}

extension GameSettingsViewController: UIPickerViewDelegate, UIPickerViewDataSource {
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
            // saving code
            UserDefaults.standard.set(selectedBeepNoiseCode, forKey: "myBeepNoiseCode")
            selectedBeepNoise = beepNoises[row]
            // saving beep noise name
            UserDefaults.standard.set(selectedBeepNoise, forKey: "myBeepNoise")
            beepNoiseTextField.text = selectedBeepNoise
        }
    }
}

