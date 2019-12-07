//
//  LocationPopUpViewController.swift
//  MusicalCaneGame
//
//  Created by occamlab on 8/9/18.
//  Copyright © 2018 occamlab. All rights reserved.
//

import UIKit

class LocationPopUpViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var beaconTextField: UITextField!
    @IBOutlet weak var newLocationTextField: UITextField!
    @IBOutlet weak var saveLocationButton: UIButton!
    
    @IBAction func saveLocationButtonAction(_ sender: Any) {
       
       // doesn't catch not filled in fields
//        if selectedBeacon != nil || newLocationTextField.text != nil {
//            performSegue(withIdentifier: "segue", sender: self)
//        } else {
//            createAlert(title: "Error", message: "Not all required fields are complete")
//        }
        dismissKeyboard()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "setBeaconDestination"), object: ["forBeacon": selectedBeacon!, "location": newLocationTextField.text!])
        dismiss(animated: true)
    }
    
    let beacons = ["Blue", "Pink", "Purple", "Rose", "White", "Yellow"]

    var selectedBeacon: String?

//    func createAlert (title:String, message:String) {
//        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
//        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)}))
//
//        self.present(alert, animated: true, completion: nil)
//    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createBeaconPicker()
        createToolBar()
    }

    func createBeaconPicker() {
        let beaconPicker = UIPickerView()
        beaconPicker.delegate = self
        beaconTextField.inputView = beaconPicker
    }
    
    func createToolBar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(LocationPopUpViewController.dismissKeyboard))
        
        toolBar.setItems([doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        beaconTextField.inputAccessoryView = toolBar
    
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
  
}

extension LocationPopUpViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return beacons.count + 1
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if row == 0 {
            return ""
        } else {
            return beacons[row-1]
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row == 0 {
            selectedBeacon = ""
        } else {
            selectedBeacon = beacons[row-1]
        }
        beaconTextField.text = selectedBeacon
    }
}
