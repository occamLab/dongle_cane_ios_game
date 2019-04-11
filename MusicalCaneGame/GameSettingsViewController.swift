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
    //Create a profile button
    
    @IBOutlet weak var newProfileButton: UIButton!
    //Profile Picker View
    @IBOutlet weak var profileBox: UITextField!
    let profilePicker = UIPickerView()
    var pickerProfiles: [String] = [String]()
    // Music Track Picker
    @IBOutlet weak var musicTrackPicker: UIButton!
    @IBOutlet weak var selectMusicText: UILabel!
    var selectedMusicTrack: String?
    var selectedSong: MPMediaItemCollection?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    var temp: URL?
    var mySong: URL?
    //Beep Noise Declaration
    let countBeepPicker = UIPickerView()
    @IBOutlet weak var beepNoiseBox: UITextField!
    @IBOutlet weak var slectBeepNoiseText: UILabel!
    let beepNoises = ["Begin", "Begin Record", "End Record", "Clypso", "Choo Choo", "Congestion", "General Beep", "Positive Beep", "Negative Beep",
                      "Keytone", "Received", "Tink", "Tock", "Tiptoes", "Tweet"]
    let beepNoiseCodes = [1110, 1113, 1114, 1022, 1023, 1071, 1052, 1054, 1053, 1075, 1013, 1103, 1104, 1034, 1016]
    var selectedBeepNoise: String?
    var selectedBeepNoiseCode: Int?
    //Sliders Declaration
    //Beep Count
    @IBOutlet weak var beepCountSlider: UISlider!
    @IBOutlet weak var beepCountLabel: UILabel!
    @IBOutlet weak var beepCountText: UILabel!
    var beepCountValue: Int?
    //Cane Legnth
    @IBOutlet weak var caneLengthSlider: UISlider!
    @IBOutlet weak var caneLengthLabel: UILabel!
    @IBOutlet weak var caneLengthText: UILabel!
    var caneLengthValue: Float?
    //Sweep Range
    @IBOutlet weak var sweepRangeSlider: UISlider!
    @IBOutlet weak var sweepRangeLabel: UILabel!
    @IBOutlet weak var sweepRangeText: UILabel!
    var sweepRangeValue: Float?
    //Save button
    @IBOutlet weak var editSaveButton: UIButton!
    var isEdit:Bool = true
    
    var dbInterface = DBInterface()
    
    
    @IBAction func newProfilePressed(_ sender: UIButton) {
        let alert = UIAlertController(title:"New Profile",message:"Enter a Profile Name",preferredStyle: .alert)
        alert.addTextField{(textField) in textField.text = "Johnny"}
        
        alert.addAction(UIAlertAction(title: "OK",style: .default, handler: {[weak alert] (_) in let textField = alert?.textFields![0]
            
            print("text field: \(textField?.text)")
            self.dbInterface.insertRow(u_name: textField!.text!, u_sweep_width: 1.0, u_cane_length: 1.0, u_beep_count: 20, u_music: "")
            
            self.pickerProfiles = self.dbInterface.getAllUserNames()
            
            self.profilePicker.reloadAllComponents()
            
            
        }))
        self.present(alert, animated: true, completion: nil)
        
        
    }
    
    
    @IBAction func chooseMusictrack(_ sender: Any) {
        let myMediaPickerVC = MPMediaPickerController.self(mediaTypes: MPMediaType.music)
        myMediaPickerVC.allowsPickingMultipleItems = false
        myMediaPickerVC.delegate = self
        self.present(myMediaPickerVC, animated: true, completion: nil)
        
        
    }
    
    @IBAction func beepCountChanged(_ sender: UISlider) {
        beepCountValue = Int(sender.value)
        beepCountLabel.text = String(beepCountValue!)
    }
    
    @IBAction func sweepRangeChanged(_ sender: UISlider) {
        sweepRangeValue = Float(sender.value)
        sweepRangeLabel.text = String(sweepRangeValue!)
    }
    
    @IBAction func caneLengthChanged(_ sender: UISlider) {
        caneLengthValue = Float(sender.value)
        caneLengthLabel.text = String(caneLengthValue!)
    }
    
    func changeOptions(b:Bool){
        musicTrackPicker.isEnabled = b
        beepNoiseBox.isEnabled = b
        beepCountSlider.isEnabled = b
        beepCountLabel.isEnabled = b
        caneLengthSlider.isEnabled = b
        caneLengthLabel.isEnabled = b
        sweepRangeSlider.isEnabled = b
        sweepRangeLabel.isEnabled = b
        
        caneLengthText.isEnabled = b
        sweepRangeText.isEnabled = b
        beepCountText.isEnabled = b
        slectBeepNoiseText.isEnabled = b
        selectMusicText.isEnabled = b
    }
    
    func loadOptions(user_name: String){
        let user_row = self.dbInterface.getRow(u_name: user_name)
        beepCountLabel.text = String(user_row![self.dbInterface.beep_count])
        sweepRangeLabel.text = String(user_row![self.dbInterface.sweep_width])
        caneLengthLabel.text = String(user_row![self.dbInterface.cane_length])
        
    }
    
    @IBAction func touchEditSave(_ sender: UIButton) {
        if(isEdit){
            //We enable the user to change values
            sender.setTitle("Save", for: .normal)
            isEdit = false
        }else{
            //We save the values the user changed
            sender.setTitle("Edit", for: .normal)
            isEdit = true
        }
        changeOptions(b:!isEdit)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        //Declare Sweep Range
        let default_username = "Default User"
        sweepRangeValue = Float(self.dbInterface.getSweepWidth(u_name: default_username)!)
        sweepRangeLabel.text = String(sweepRangeValue!)
        caneLengthValue = Float(self.dbInterface.getCaneLength(u_name: default_username)!)
        caneLengthLabel.text = String(caneLengthValue!)
        beepCountValue = Int(self.dbInterface.getBeepCount(u_name: default_username)!)
        beepCountLabel.text = String(beepCountValue!)
        
        //Populate Picker
        pickerProfiles = self.dbInterface.getAllUserNames()
        
        createProfilePicker()
        
        //Create pickers
        createBeepNoisePicker(countNoisePicker: countBeepPicker)
        createToolbar()
        changeOptions(b:!isEdit)
        

    
//        let defaults = UserDefaults.standard
//        let mySong = defaults.object(forKey: UserDefaultsKeys.NSRUL.rawValue) as! Data
//        print(mySong ?? "hi")
        

        // Do any additional setup after loading the view.
    }
    
    func createProfilePicker() {
        profilePicker.delegate = self
        profilePicker.dataSource = self
        profileBox.inputView = profilePicker
    }
    func createBeepNoisePicker(countNoisePicker: UIPickerView) {
        countNoisePicker.delegate = self
        beepNoiseBox.inputView = countNoisePicker
    }
    func createToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(SoundViewController.dismissKeyboard))
        
        toolbar.setItems([doneButton], animated: false)
        toolbar.isUserInteractionEnabled = true
        
        beepNoiseBox.inputAccessoryView = toolbar
        profileBox.inputAccessoryView = toolbar
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
            beepNoiseBox.text = n
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
        }else if(pickerView == profilePicker){
            return pickerProfiles.count
        }
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == countBeepPicker {
            return beepNoises[row]
        }else if(pickerView == profilePicker){
            return pickerProfiles[row]
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
            beepNoiseBox.text = selectedBeepNoise
        }else if(pickerView == profilePicker){
            profileBox.text = pickerProfiles[row]
            loadOptions(user_name: profileBox.text!)
        }
    }
}

