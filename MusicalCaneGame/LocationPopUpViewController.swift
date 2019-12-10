//
//  LocationPopUpViewController.swift
//  MusicalCaneGame
//
//  Created by occamlab on 8/9/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import SQLite

class LocationPopUpViewController: UIViewController, UIPopoverPresentationControllerDelegate, RecorderViewControllerDelegate {
    func didStartRecording() {
    }
    
    @IBOutlet weak var actionPicker: UIPickerView!
    func didFinishRecording(audioFileURL: URL) {
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        // TODO: fix unwrapping
        print("url", audioFileURL.absoluteString)
        dbInterface.updateBeaconVoiceNote(u_name: selectedProfile, b_name: selectedBeacon!, voiceNote_URL: audioFileURL.lastPathComponent)
    }
    
    let dbInterface = DBInterface()

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var beaconTextField: UITextField!
    @IBOutlet weak var newLocationTextField: UITextField!
    
    let beacons = ["Blue", "Pink", "Purple", "Rose", "White", "Yellow"]

    var selectedBeacon: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        beaconTextField.text = selectedBeacon

        // Connect data:
        self.actionPicker.delegate = self
        self.actionPicker.dataSource = self
        createToolBar()
        
        newLocationTextField.addTarget(self, action: #selector(locationTextFieldChanged), for: .editingChanged)
    }
    
    @objc func locationTextFieldChanged() {
        // TODO: could replace with direct call to DB interface    
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "setBeaconDestination"), object: ["forBeacon": selectedBeacon!, "location": newLocationTextField.text!])
    }
    
    func createToolBar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(LocationPopUpViewController.dismissKeyboard))
        
        toolBar.setItems([doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        beaconTextField.inputAccessoryView = toolBar
        
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        // TODO: fix unwrapping
        if let row = dbInterface.getBeaconNames(u_name: selectedProfile, b_name: selectedBeacon!) {
            newLocationTextField.text = try! row.get(dbInterface.locationText)
            actionPicker.selectRow(try! row.get(dbInterface.beaconStatus), inComponent: 0, animated: false)
        }
    
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func recordVoiceNote(_ sender: Any) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "handleChangeInAudioRecording"), object: true)

        let popoverContent = RecorderViewController()
        //says that the recorder should dismiss tiself when it is done
        popoverContent.shouldAutoDismiss = true
        popoverContent.delegate = self
        popoverContent.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: popoverContent, action: #selector(popoverContent.doneWithRecording))
        let nav = UINavigationController(rootViewController: popoverContent)
        nav.modalPresentationStyle = .popover
        let popover = nav.popoverPresentationController
        popover?.delegate = self
        popover?.sourceView = self.view
        popover?.sourceRect = CGRect(x: 0, y: 10, width: 0,height: 0)
        self.present(nav, animated: true, completion: nil)
    }
}

extension LocationPopUpViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 3
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        print("populating")
        if row == 0 {
            return "Use Location Text"
        } else if row == 1 {
            return "Use Voice Note"
        } else {
            return "Deactivate This Beacon"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        // TODO: fix unwrapping
        dbInterface.updateBeaconStatus(u_name: selectedProfile, b_name: selectedBeacon!, status: row)
    }
}
