/**
//  GameSettingsViewController.swift
//  MusicalCaneGame
//
//  Created by Anna Griffin on 10/5/18.
//  Copyright © 2018 occamlab. All rights reserved.
*/

import UIKit
import CoreBluetooth
import AVFoundation
import MediaPlayer

/**
Add sample doc for GameSetitngs
*/
class GameSettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var newProfileButton: UIButton!
    var selectedProfile: String = "Default User"
    ///Profile Picker View
    @IBOutlet weak var profileBox: UITextField!
    let profilePicker = UIPickerView()
    var pickerProfiles: [String] = [String]()
    /// Music Track Picker
    @IBOutlet weak var musicTrackPicker: UIButton!
    @IBOutlet weak var selectMusicText: UILabel!
    var selectedMusicTrack: String?
    var selectedSongTitle: String?
    var selectedSong: MPMediaItemCollection?
    let myMediaPlayer = MPMusicPlayerApplicationController.applicationQueuePlayer
    var mySong: URL?
    var mySongStr: String?
    ///Beep Noise Declaration
    let countBeepPicker = UIPickerView()
    @IBOutlet weak var beepNoiseBox: UITextField!
    @IBOutlet weak var selectBeepNoiseText: UILabel!
    let beepNoises = ["Begin", "Begin Record", "End Record", "Clypso", "Choo Choo", "Congestion", "General Beep", "Positive Beep", "Negative Beep",
                      "Keytone", "Received", "Tink", "Tock", "Tiptoes", "Tweet"]
    let beepNoiseCodes = [1110, 1113, 1114, 1022, 1023, 1071, 1052, 1054, 1053, 1075, 1013, 1103, 1104, 1034, 1016]
    var selectedBeepNoise: String?
    var selectedBeepNoiseCode: Int?
    ///Beep Count
    @IBOutlet weak var beepCountSlider: UISlider!
    @IBOutlet weak var beepCountLabel: UILabel!
    @IBOutlet weak var beepCountText: UILabel!
    var beepCountValue: Int?
    ///Cane Legnth
    @IBOutlet weak var caneLengthSlider: UISlider!
    @IBOutlet weak var caneLengthLabel: UILabel!
    @IBOutlet weak var caneLengthText: UILabel!
    var caneLengthValue: Float?
    ///Sweep Range
    @IBOutlet weak var sweepRangeSlider: UISlider!
    @IBOutlet weak var sweepRangeLabel: UILabel!
    @IBOutlet weak var sweepRangeText: UILabel!
    var sweepRangeValue: Float?

    // skill level/ sweep tolerance
    @IBOutlet weak var skillLevelLabel: UILabel!
    @IBOutlet weak var skillLevelBox: UITextField!
    let sweepTolerancePicker = UIPickerView()
    let sweepTolerancePickerData = ["Level 1", "Level 2", "Level 3", "Level 4", "Level 5"]
    let skillLevelSweepToTolerance = ["Level 1": 15, "Level 2": 9, "Level 3": 6, "Level 4": 4, "Level 5": 2]
    let sweepToleranceToSkillLevel = [15: "Level 1", 9: "Level 2", 6: "Level 3", 4: "Level 4", 2: "Level 5"]
    var sweepToleranceValue = 15
    
    //Save button
    @IBOutlet weak var editSaveButton: UIButton!
    var isEdit:Bool = true
    ///Database of user information
    var dbInterface = DBInterface.shared


    /**
        This function runs when the user selects the `Create Profile` option.
        It will
        1. Open an alert to request the name of the profile
        2. When a name is entered, save the name with default settings in the database
        3. Reset the loaded name and options to the newly entered name
        4. Reload the pickerview to update the name and options

        - Parameter sender: The UI button itself
    */
    @IBAction func newProfilePressed(_ sender: UIButton) {
        let alert = UIAlertController(title:"New Profile",message:"Enter a Profile Name",preferredStyle: .alert)
        alert.addTextField{(textField) in textField.text = "Johnny"}

        alert.addAction(UIAlertAction(title: "OK",style: .default, handler: {[weak alert] (_) in let textField = alert?.textFields![0]

            print("text field: \(textField?.text)")

            self.dbInterface.insertRow(u_name: textField!.text!, u_sweep_width: 20.0, u_cane_length: 40.0, u_beep_count: 20, u_music: "Select Music", u_beep_noise: "Begin Record", u_music_url: "", u_sweep_tolerance: 15)
            

            self.pickerProfiles = self.dbInterface.getAllUserNames()
            self.profileBox.text = textField!.text!
            UserDefaults.standard.set(self.profileBox.text, forKey: "currentProfile")
            self.selectedProfile = textField!.text!
            self.loadOptions()
            self.profilePicker.reloadAllComponents()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    /**
        This function runs when the user elects to change the song.

        - Parameter sender: The UI button itself
    */
    @IBAction func chooseMusictrack(_ sender: Any) {
        let myMediaPickerVC = MPMediaPickerController.self(mediaTypes: MPMediaType.music)
        myMediaPickerVC.allowsPickingMultipleItems = false
        myMediaPickerVC.delegate = self
        self.present(myMediaPickerVC, animated: true, completion: nil)
    }

    /**
        This function runs when the user changes the beep count slider. It will
        change the text on the screen and global variables to reflect the new value.

        - Parameter sender: The UI Slider itself
    */
    @IBAction func beepCountChanged(_ sender: UISlider) {
        beepCountValue = Int(sender.value)
        beepCountLabel.text = String(beepCountValue!)
    }
    /**
        This function runs when the user changes the sweep range slider. It will
        change the text on the screen and global variables to reflect the new value.

        - Parameter sender: The UI Slider itself
    */
    @IBAction func sweepRangeChanged(_ sender: UISlider) {
        sweepRangeValue = Float(sender.value)
        sweepRangeLabel.text = String(format:"%.1f",sweepRangeValue!) + " inches"
    }
    /**
        This function runs when the user changes the can length slider. It will
        change the text on the screen and global variables to reflect the new value.

        - Parameter sender: The UI Slider itself
    */
    @IBAction func caneLengthChanged(_ sender: UISlider) {
        caneLengthValue = Float(sender.value)
        caneLengthLabel.text = String(format:"%.1f",caneLengthValue!) + " inches"
    }

    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        print(sweepTolerancePickerData[row])
    }
    /**
        This function will disable and grey out all the user options on the screen

        - Parameter b: boolean whether or not to enable the options
    */
    func changeOptions(b:Bool){
        musicTrackPicker.isEnabled = b
        beepNoiseBox.isEnabled = b
        beepCountSlider.isEnabled = b
        beepCountLabel.isEnabled = b
        caneLengthSlider.isEnabled = b
        caneLengthLabel.isEnabled = b
        sweepRangeSlider.isEnabled = b
        sweepRangeLabel.isEnabled = b
        skillLevelBox.isEnabled = b
        skillLevelLabel.isEnabled = b
        

        caneLengthText.isEnabled = b
        sweepRangeText.isEnabled = b
        beepCountText.isEnabled = b
        selectBeepNoiseText.isEnabled = b
        selectMusicText.isEnabled = b
    }

    /**
        This function will use the global variable `selectedProfile` to load a relevant settings for the selected user and update the UI
    */
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
        beepCountLabel.text = String(Int(beepCountSlider.value))
        sweepRangeValue = Float(user_row![self.dbInterface.sweep_width])
        sweepRangeSlider.setValue(sweepRangeValue!, animated: false)
        sweepRangeLabel.text = String(Double(sweepRangeSlider.value).roundTo(places: 2)) + " inches"
        caneLengthValue = Float(user_row![self.dbInterface.cane_length])
        caneLengthSlider.setValue(caneLengthValue!, animated: false)
        caneLengthLabel.text = String(Double(caneLengthSlider.value).roundTo(places: 2)) + " inches"
        
        // User skill level
        sweepToleranceValue = Int(user_row![self.dbInterface.sweep_tolerance])
        let skillLevel = sweepToleranceToSkillLevel[sweepToleranceValue]
        if skillLevel != nil {
            skillLevelBox.text = skillLevel!
        } else {
            skillLevelBox.text = "Level 1"
        }
    }

    /**
        This function runs when the user selects the edit/save button.
        - If the button current says edit, it will ungrey and enable all the options
        - If the button says save, it will grey the boxes and save their current value in the database

        - Parameter sender: The UI button itself
    */
    @IBAction func touchEditSave(_ sender: UIButton) {
        if(isEdit){
            //We enable the user to change values
            sender.setTitle("Save", for: .normal)
            isEdit = false
        }else{
            //We save the values the user changed
            sender.setTitle("Edit", for: .normal)
            // TODO once we have the name picker working, put it in here
            dbInterface.updateRow(u_name: profileBox.text!, u_sweep_width: Double(sweepRangeValue!), u_cane_length: Double(caneLengthValue!), u_beep_count: Int(beepCountValue!),
                u_music: selectedSongTitle!,
                u_beep_noise: selectedBeepNoise!,
                u_music_url: mySongStr!,
                u_sweep_tolerance: Double(sweepToleranceValue))
            isEdit = true
        }
        changeOptions(b:!isEdit)
    }

    /**
        This function runs when the the view loads (duh).
        It will
        1. Load the superview
        2. Load the side menu
        3. Populate the potential profiles
        4. Populate the beeps
        5. Disable the current options
        6. Load the current user and their options

        - Parameter sender: The UI Slider itself
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        //Declare Sweep Range

        //Populate Picker
        pickerProfiles = self.dbInterface.getAllUserNames()
        print(pickerProfiles)
        createProfilePicker()
        
        self.sweepTolerancePicker.delegate = self
        self.sweepTolerancePicker.dataSource = self
        self.skillLevelBox.inputView = sweepTolerancePicker
        
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
    /**
        Defines a toolbar that enables you to pick from options and exit by selecting a done key
    */
    func createToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(self.dismissKeyboard))

        toolbar.setItems([doneButton], animated: false)
        toolbar.isUserInteractionEnabled = true

        beepNoiseBox.inputAccessoryView = toolbar
        profileBox.inputAccessoryView = toolbar
        skillLevelBox.inputAccessoryView = toolbar
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
}


extension GameSettingsViewController: MPMediaPickerControllerDelegate {
    /**
      When song is selected, save the data in the appropriate global variables.
    */
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        myMediaPlayer.setQueue(with: mediaItemCollection)
        selectedSong = mediaItemCollection
        let mySongObj = selectedSong?.items[0]
        mySong = mySongObj?.value(forProperty:MPMediaItemPropertyAssetURL) as? URL
        guard let mySongURL = mySong else {
            if mySongObj!.isCloudItem {
                let alertController = UIAlertController(title: "Media not found on device", message:
                    "Perhaps you need to download this from iCloud.", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .default))
                mediaPicker.present(alertController, animated: true, completion: nil)
            } else if mySongObj!.hasProtectedAsset {
                let alertController = UIAlertController(title: "Not authorized to play media", message:
                    "Something is off with your iTunes settings.", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .default))
                mediaPicker.present(alertController, animated: true, completion: nil)
            }
            return
        }
        mySongStr = mySongURL.absoluteString
        selectedSongTitle = selectedSong?.items[0].title
        musicTrackPicker.setTitle(selectedSongTitle, for: .normal)
        mediaPicker.dismiss(animated: true, completion: nil)

    }

    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPicker.dismiss(animated: true, completion: nil)
    }

}

extension GameSettingsViewController {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    /**
      return the number of options in the appropriate picker view
    */
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == countBeepPicker {
            return beepNoises.count
        }else if(pickerView == profilePicker){
            return pickerProfiles.count
        } else if (pickerView == sweepTolerancePicker) {
            return sweepTolerancePickerData.count
        }
        return 0
    }
    /**
        return the selected option from the right view
    */
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == countBeepPicker {
            return beepNoises[row]
        }else if(pickerView == profilePicker){
            return pickerProfiles[row]
        } else if (pickerView == sweepTolerancePicker) {
            print("sweep tolerance!")
            return sweepTolerancePickerData[row]
        }
        return ""
    }
    /**
        Load the appropriate data whenever you mouse over a row
    */
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
        } else if (pickerView == sweepTolerancePicker) {
            let level = sweepTolerancePickerData[row]
            skillLevelBox.text = level

            let sv: Int? = skillLevelSweepToTolerance[level]
            if sv != nil {
                sweepToleranceValue = sv!
            } else {
                print("sweeptolerance is nil")
            }
        }
    }
}
