//
//  LocationPopUpViewController.swift
//  MusicalCaneGame
//
//  Created by occamlab on 8/9/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit
import SQLite
import FlexColorPicker

class LocationPopUpViewController: UIViewController, UIPopoverPresentationControllerDelegate, RecorderViewControllerDelegate, ColorPickerDelegate {
    
    func colorPicker(_ colorPicker: ColorPickerController, selectedColor: UIColor, usingControl: ColorControl) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "setBeaconColor"), object: ["forBeacon": self.selectedMinor!, "colorHexValue": selectedColor.hexValue()])
        self.selectedColor = selectedColor
        beaconColorButton.backgroundColor = self.selectedColor
    }
    
    func colorPicker(_ colorPicker: ColorPickerController, confirmedColor: UIColor, usingControl: ColorControl) {
        print("confirmed color")
    }
    @IBOutlet weak var beaconColorButton: UIButton!
    
    @IBAction func beaconColorButtonPressed(_ sender: Any) {
        let popoverContent = DefaultColorPickerViewController()
               popoverContent.delegate = self

               popoverContent.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: popoverContent, action: #selector(popoverContent.dismissPopover))
               if let currentColor = self.selectedColor {
                   popoverContent.selectedColor = currentColor
               }
               let nav = UINavigationController(rootViewController: popoverContent)
               nav.modalPresentationStyle = .popover
               let popover = nav.popoverPresentationController
               popover?.sourceView = self.view
               popover?.sourceRect = CGRect(x: 0, y: 10, width: 0,height: 0)

               self.present(nav, animated: true, completion: nil)
    }

    @IBOutlet weak var beaconLabel: UILabel!
    @IBOutlet weak var actionPicker: UIPickerView!
    
    func didStartRecording() {
    }

    func didFinishRecording(audioFileURL: URL) {
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        // TODO: fix unwrapping
        print("url", audioFileURL.absoluteString)
        dbInterface.updateBeaconVoiceNote(u_name: selectedProfile, b_minor: selectedMinor!, voiceNote_URL: audioFileURL.lastPathComponent)
    }
    
    let dbInterface = DBInterface.shared

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var beaconTextField: UITextField!
    @IBOutlet weak var newLocationTextField: UITextField!
    
    var selectedBeacon: String?
    var selectedMinor: Int?
    var selectedColor: UIColor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        beaconColorButton.backgroundColor = selectedColor
        beaconColorButton.layer.borderWidth = 2
        beaconColorButton.layer.borderColor = UIColor.black.cgColor

        beaconTextField.text = selectedBeacon

        // Connect data:
        self.actionPicker.delegate = self
        self.actionPicker.dataSource = self
        createToolBar()
        
        newLocationTextField.addTarget(self, action: #selector(locationTextFieldChanged), for: .editingChanged)
        
        beaconTextField.addTarget(self, action: #selector(beaconNameEdited), for: .editingChanged)
    }
    
    @IBAction func forgetButtonPressed(_ sender: Any) {
        // Create the alert controller
           let alertController = UIAlertController(title: "Are you sure?", message: "Forgetting the beacon will result in it not activating in the game.", preferredStyle: .alert)

           // Create the actions
           let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
               UIAlertAction in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "forgetBeacon"), object: ["forBeacon": self.selectedMinor!])
            self.dismissKeyboard()
            self.dismiss(animated: true)
           }
           let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) {
               UIAlertAction in
            }

           // Add the actions
           alertController.addAction(okAction)
           alertController.addAction(cancelAction)

           // Present the controller
           self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func locationTextFieldChanged() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "setBeaconDestination"), object: ["forBeacon": selectedMinor!, "location": newLocationTextField.text!])
    }
    
    func createToolBar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(LocationPopUpViewController.dismissKeyboard))
        
        toolBar.setItems([doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        newLocationTextField.inputAccessoryView = toolBar
        
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        // TODO: fix unwrapping
        if let row = dbInterface.getBeaconNames(u_name: selectedProfile, b_minor: selectedMinor!) {
            newLocationTextField.text = try! row.get(dbInterface.locationText)
            actionPicker.selectRow(try! row.get(dbInterface.beaconStatus), inComponent: 0, animated: false)
        }
    
    }
    
    @objc func beaconNameEdited(_ sender: Any) {
        if let newName = beaconTextField.text, newName != "Unknown" {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "setGlobalBeaconName"), object: ["forBeacon": selectedMinor!, "globalName": newName])
            
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func recordVoiceNote(_ sender: Any) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "handleChangeInAudioRecording"), object: true)

        let popoverContent = RecorderViewController()
        //says that the recorder should dismiss itself when it is done
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
    
    @objc func dismissWindow() {
        dismiss(animated: true)
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
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "setBeaconStatus"), object: ["forBeacon": selectedMinor!, "status": row])
    }
}

extension DefaultColorPickerViewController {
    @objc func dismissPopover() {
        dismiss(animated: true)
    }
}
