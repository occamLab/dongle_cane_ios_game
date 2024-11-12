//
//  ProgressBarView.swift
//  MusicalCaneGame
//
//  Created by occamlab on 11/12/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import UIKit
import SwiftUI

class ProgressBarViewController: UIViewController {
    
    @IBOutlet weak var swiftUIContainer: UIView!
    let progressBarView = UIHostingController(rootView: ProgressBarView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChildViewController(progressBarView)
        progressBarView.view.frame = swiftUIContainer.bounds
        swiftUIContainer.addSubview(progressBarView.view)
    }
}

struct ProgressBarView: View {
    @ObservedObject var sensorDriver = SensorDriver.shared
    
    var body: some View {
        Text("Connected to device: \(sensorDriver.newDeviceName)")
    }
}
