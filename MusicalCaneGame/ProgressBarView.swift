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

    let progressBarView = UIHostingController(rootView: ProgressBarView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChildViewController(progressBarView)
        progressBarView.view.frame = self.view.bounds
        self.view.addSubview(progressBarView.view)
    }
}

struct ProgressBarView: View {
    @ObservedObject var sensorDriver = SensorDriver.shared
    
    var body: some View {
        Text("Connected to device: \(sensorDriver.newDeviceName)")
    }
}
