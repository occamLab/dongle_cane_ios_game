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
    
    var selectedMusicTrack: String?
    @IBAction func chooseMusictrack(_ sender: Any) {
        let myMediaPickerVC = MPMediaPickerController.self(mediaTypes: MPMediaType.music)
        myMediaPickerVC.allowsPickingMultipleItems = false
        myMediaPickerVC.delegate = self
        self.present(myMediaPickerVC, animated: true, completion: nil)
        
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
    
//    var temp: NSURL?
    

    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        createBeepNoisePicker(countNoisePicker: countBeepPicker)
        createToolbar()
        
        

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
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(SoundModeViewController.dismissKeyboard))
        
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
    
    func sideMenu() {
        
        if revealViewController() != nil {
            
            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            revealViewController().rearViewRevealWidth = 250
            
            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
            
        }
    }
    
    struct GlobalVariable {
        static var mySelectedSong = NSURL();
        static var mySelectedBeepNoise = String();
        static var mySelectedBeepNoiseCode = Int();
    }

}

extension GameSettingsViewController: MPMediaPickerControllerDelegate {
    
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        myMediaPlayer.setQueue(with: mediaItemCollection)
        selectedSong = mediaItemCollection
//        print(type(of:selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL)))
//        temp = selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL
//        print(temp)
        GlobalVariable.mySelectedSong = selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL) as! NSURL
        print(type(of:selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL)))
//        print(type(of:selectedSong?.items[0]))
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
            GlobalVariable.mySelectedBeepNoiseCode = selectedBeepNoiseCode!
            selectedBeepNoise = beepNoises[row]
            GlobalVariable.mySelectedBeepNoise = selectedBeepNoise!
            beepNoiseTextField.text = selectedBeepNoise
        }
    }
}

