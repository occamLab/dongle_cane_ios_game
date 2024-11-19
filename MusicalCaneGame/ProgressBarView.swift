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
<<<<<<< Updated upstream

    let progressBarView = UIHostingController(rootView: ProgressBarView())
    
=======
    @IBOutlet weak var swiftUIContainer: UIView!
    var progressBarView: UIHostingController<ProgressBarView>!

>>>>>>> Stashed changes
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize SwiftUI view
        progressBarView = UIHostingController(rootView: ProgressBarView())
        
        // Add the SwiftUI view as a child view
        addChildViewController(progressBarView)
<<<<<<< Updated upstream
        progressBarView.view.frame = self.view.bounds
        self.view.addSubview(progressBarView.view)
=======
        progressBarView.view.translatesAutoresizingMaskIntoConstraints = false
        swiftUIContainer.addSubview(progressBarView.view)
        progressBarView.didMove(toParent: self)
        
        // Set constraints to match container
        NSLayoutConstraint.activate([
            progressBarView.view.leadingAnchor.constraint(equalTo: swiftUIContainer.leadingAnchor),
            progressBarView.view.trailingAnchor.constraint(equalTo: swiftUIContainer.trailingAnchor),
            progressBarView.view.topAnchor.constraint(equalTo: swiftUIContainer.topAnchor),
            progressBarView.view.bottomAnchor.constraint(equalTo: swiftUIContainer.bottomAnchor)
        ])
>>>>>>> Stashed changes
    }
}

struct ProgressBarView: View {
    @ObservedObject var sensorDriver = SensorDriver.shared

    var body: some View {
        GeometryReader { geometry in
            // Calculate relative widths
            let totalSize = sensorDriver.underflowSize
                + sensorDriver.validZoneSize
                + sensorDriver.overflowSize
            let underflowWidth = CGFloat(sensorDriver.underflowSize / totalSize) * geometry.size.width
            let validZoneWidth = CGFloat(sensorDriver.validZoneSize / totalSize) * geometry.size.width
            let overflowWidth = CGFloat(sensorDriver.overflowSize / totalSize) * geometry.size.width

            HStack(spacing: 0) {
                // Underflow progress bar
                Rectangle()
                    .fill(Color.red)
                    .frame(width: underflowWidth)
                    .overlay(
                        ProgressView(value: sensorDriver.underflowProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .frame(width: underflowWidth)
                    )

                // Valid zone progress bar
                Rectangle()
                    .fill(Color.green)
                    .frame(width: validZoneWidth)
                    .overlay(
                        ProgressView(value: sensorDriver.validZoneProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(width: validZoneWidth)
                    )

                // Overflow progress bar
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: overflowWidth)
                    .overlay(
                        ProgressView(value: sensorDriver.overflowProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: overflowWidth)
                    )
            }
            .cornerRadius(5) // Optional rounded corners
            .frame(height: 20) // Set height for the progress bars
        }
        .padding()
        .onAppear {
            sensorDriver.startQuaternionStreaming()
        }
        .onReceive(sensorDriver.$underflowProgress) { newValue in
            print("Underflow Progress Updated: \(newValue)")
        }
    }
}
