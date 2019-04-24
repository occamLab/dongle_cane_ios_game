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
    var selectedProfile: String = "Default User"
    //Profile Picker View
    @IBOutlet weak var profileBox: UITextField!
    let profilePicker = UIPickerView()
    var pickerProfiles: [String] = [String]()
    // Music Track Picker
    @IBOutlet weak var musicTrackPicker: UIButton!
    @IBOutlet weak var selectMusicText: UILabel!
    var selectedMusicTrack: String?
    var selectedSongTitle: String?
    var selectedSong: MPMediaItemCollection?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    var mySong: URL?
    var mySongStr: String?
    //Beep Noise Declaration
    let countBeepPicker = UIPickerView()
    @IBOutlet weak var beepNoiseBox: UITextField!
    
    @IBOutlet weak var selectBeepNoiseText: UILabel!
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
            self.dbInterface.insertRow(u_name: textField!.text!, u_sweep_width: 1.0, u_cane_length: 1.0, u_beep_count: 20, u_music: "Select Music", u_beep_noise: "Select Beep", u_music_url: "")
            
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
        sweepRangeLabel.text = String(format:"%.1f",sweepRangeValue!) + " in"
    }
    
    @IBAction func caneLengthChanged(_ sender: UISlider) {
        caneLengthValue = Float(sender.value)
        caneLengthLabel.text = String(format:"%.1f",caneLengthValue!) + " in"
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
        selectBeepNoiseText.isEnabled = b
        selectMusicText.isEnabled = b
    }
    
    func loadOptions(){
        let user_row = self.dbInterface.getRow(u_name: selectedProfile)
        
        profileBox.text = selectedProfile
        //Change beep noise
        selectedBeepNoise = String(user_row![self.dbInterface.beep_noise])
        beepNoiseBox.text = selectedBeepNoise
        
        //Change Music Title
        selectedSongTitle = String(user_row![self.dbInterface.music])
        mySongStr = String(user_row![self.dbInterface.music_url])
        musicTrackPicker.setTitle(selectedSongTitle, for: .normal)
        
        //For the sliders
        beepCountValue = user_row![self.dbInterface.beep_count]
        beepCountSlider.setValue(Float(beepCountValue!), animated: false)
        beepCountLabel.text = String(beepCountSlider.value)
        sweepRangeValue = Float(user_row![self.dbInterface.sweep_width])
        sweepRangeSlider.setValue(sweepRangeValue!, animated: false)
        sweepRangeLabel.text = String(sweepRangeSlider.value)
        caneLengthValue = Float(user_row![self.dbInterface.cane_length])
        caneLengthSlider.setValue(caneLengthValue!, animated: false)
        caneLengthLabel.text = String(caneLengthSlider.value)
        
    }
    
    @IBAction func touchEditSave(_ sender: UIButton) {
        if(isEdit){
            //We enable the user to change values
            sender.setTitle("Save", for: .normal)
            isEdit = false
        }else{
            //We save the values the user changed
            sender.setTitle("Edit", for: .normal)
            // TODO once we have the name picker working, put it in here
            do{
                try dbInterface.updateRow(u_name: profileBox.text!, u_sweep_width: Double(sweepRangeValue!), u_cane_length: Double(caneLengthValue!), u_beep_count: Int(beepCountValue!),
                    u_music: selectedSongTitle!,
                    u_beep_noise: selectedBeepNoise!,
                    u_music_url: mySongStr!)
            }catch{
                print("error updating users table in game settings: \(error)")
            }
            isEdit = true
        }
        changeOptions(b:!isEdit)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        //Declare Sweep Range

        //Populate Picker
        pickerProfiles = self.dbInterface.getAllUserNames()
        
        createProfilePicker()
        
        //Create pickers
        createBeepNoisePicker(countNoisePicker: countBeepPicker)
        createToolbar()
        changeOptions(b:!isEdit)
        //Load db info
        if (UserDefaults.standard.string(forKey: "currentProfile") == nil){
            UserDefaults.standard.set("Default User", forKey: "currentProfile")
        }
        selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        loadOptions()

    
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
    
//    override func viewDidAppear(_ animated: Bool) {
//
//            // set selected song button
//        if let y = UserDefaults.standard.string(forKey: "mySongTitle") {
//            musicTrackPicker.setTitle(y, for: .normal)
//        }
//            // set beep noise text field
//        if let n = UserDefaults.standard.string(forKey: "myBeepNoise") {
//            beepNoiseBox.text = n
//        }
//
//    }
    

    
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
        mySong = selectedSong?.items[0].value(forProperty:MPMediaItemPropertyAssetURL) as? URL
        mySongStr = mySong!.absoluteString
        
        //Configuration.setUserProperty(forUser: <#T##String#>, key: <#T##String#>, value: <#T##String#>)
        //Will be deleted and replaced with db functions
        // artist
        //UserDefaults.standard.set(selectedSong?.items[0].albumArtist, forKey: "myArtist")
        // URL
        //UserDefaults.standard.set(mySong, forKey: "mySongURL")
        //Song title
        selectedSongTitle = selectedSong?.items[0].title
        //UserDefaults.standard.set(selectedSongTitle, forKey: "mySongTitle")
        
        
        musicTrackPicker.setTitle(selectedSongTitle, for: .normal)
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
            UserDefaults.standard.set(profileBox.text, forKey: "currentProfile")
            selectedProfile = pickerProfiles[row]
            loadOptions()
        }
    }
}

