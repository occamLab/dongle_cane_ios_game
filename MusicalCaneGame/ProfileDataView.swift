//
//  ProfileDataView.swift
//  MusicalCaneGame
//
//  Created by occamlab on 12/3/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import UIKit
import SwiftUI
import Charts
import Foundation
import FirebaseFirestore

/// Represents a single session's sweep data, target, and tolerance
struct SessionData: Identifiable {
    let id = UUID() // Unique identifier for each session
    let sweepDistances: [Float] // Recorded sweep distances for the session
    let targetDistance: Float // Target distance for sweeps
    let tolerance: Float // Tolerance percentage (e.g., 0.05 for 5%)
    // Timestamps from Firebase
    let startTimestamp: Timestamp
    let endTimestamp: Timestamp

    /// Lower bound for valid sweep distances
    var lowerBound: Float {
        targetDistance * (1 - tolerance)
    }

    /// Upper bound for valid sweep distances
    var upperBound: Float {
        targetDistance * (1 + tolerance)
    }
}


class ProfileDataViewController: UIViewController {
  
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    let profileDataView = UIHostingController(rootView: ProfileDataView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        addChildViewController(profileDataView)
        profileDataView.view.frame = self.view.bounds
        self.view.addSubview(profileDataView.view)
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

struct ProfileDataView: View {
    @State private var showingAlert: Bool = false
    @State private var selectedIndex: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @ObservedObject var sensorDriver = SensorDriver.shared
    
    // FIX: Add timestamps to the points properly
    let sessionData = [
        SessionData(sweepDistances: [10, 20, 30, 40, 25, 35], targetDistance: 30, tolerance: 0.1, startTimestamp: Timestamp.init(), endTimestamp: Timestamp.init()),
        SessionData(sweepDistances: [30, 30, 35, 45, 50], targetDistance: 30, tolerance: 0.1, startTimestamp: Timestamp.init(), endTimestamp: <#T##Timestamp#>.init()),
        SessionData(sweepDistances: [15, 25, 20, 30, 35, 40], targetDistance: 30, tolerance: 0.1, startTimestamp: Timestamp.init(), endTimestamp: <#T##Timestamp#>.init()),
    ]
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selectedIndex) {
                    Text("History").tag(0)
                    Text("Single Session").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedIndex == 0 {
                    // History View with Bar Plot
                    HStack {
                        DatePicker(
                            "Start",
                            selection: $startDate,
                            displayedComponents: [.date]
                        )
                        DatePicker(
                            "End",
                            selection: $endDate,
                            displayedComponents: [.date]
                        )
                    }
                    .padding(.horizontal)
                    
                    Text("Session Overview")
                        .font(.headline)
                        .padding(.top)

                    BarPlotView(sessionData: sessionData)
                        .frame(height: 300)
                        .padding()
                } else {
                    // Single Session View with Scatter Plot
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .padding(.horizontal)

                    Text("Sweep Distances")
                        .font(.headline)
                        .padding(.top)
                    // TODO: Fetch the session data from DB
                    if sessionData.isEmpty {
                        Text("No sweeps recorded yet.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        // TODO: Fetch the session data from DB
                        ScatterPlotView(
                            dataPoints: sessionData[0].sweepDistances,
                            targetDistance: 30,
                            percentTolerance: 0.05
                        )
                        .frame(height: 300)
                        .padding()
                    }
                    
                    Button("Delete Session") {
                        showingAlert = true
                    }
                    .padding()
                    .background(Color(.red))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .alert(isPresented: $showingAlert) {
                        Alert(
                            title: Text("Are you sure you want to delete this session?"),
                            message: Text("This will permanently this session's data from this profile."),
                            primaryButton: .destructive(Text("Delete")) {
                                print("Deleting...")
                                //TODO: Delete session logic goes here
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                Button("Export Graph") {
                    //TODO: Export graph as png or pdf or something here
                }
                .padding()
            }
            .navigationTitle("Progress Tracking Data")
        }
    }
}



struct BarPlotView: View {
    let sessionData: [SessionData]

    var body: some View {
        Chart {
            ForEach(sessionData.indices, id: \.self) { sessionIndex in
                let session = sessionData[sessionIndex]

                // Calculate underflow, valid, and overflow counts
                let underflow = session.sweepDistances.filter { $0 < session.lowerBound }.count
                let valid = session.sweepDistances.filter { $0 >= session.lowerBound && $0 <= session.upperBound }.count
                let overflow = session.sweepDistances.filter { $0 > session.upperBound }.count

                // Add stacked bars for each category
                BarMark(
                    x: .value("Session", "Session \(sessionIndex + 1)"),
                    y: .value("Underflow", underflow)
                )
                .foregroundStyle(Color.red)

                BarMark(
                    x: .value("Session", "Session \(sessionIndex + 1)"),
                    y: .value("Valid", valid)
                )
                .foregroundStyle(Color.green)

                BarMark(
                    x: .value("Session", "Session \(sessionIndex + 1)"),
                    y: .value("Overflow", overflow)
                )
                .foregroundStyle(Color.blue)
            }
        }
        .chartYAxisLabel("Count", position: .leading)
        .chartXAxisLabel("Session", position: .bottom)
        .padding()
    }
}


struct ScatterPlotView: View {
    let dataPoints: [Float]
    let targetDistance: Float
    let percentTolerance: Float

    var body: some View {
        Chart {
            let lowerBound = targetDistance * (1 - percentTolerance)
            let upperBound = targetDistance * (1 + percentTolerance)
            // Scatter points
            ForEach(dataPoints.indices, id: \.self) { index in
                let distance = dataPoints[index]
                
                PointMark(
                    x: .value("Index", index),
                    y: .value("Distance", distance)
                )
                .foregroundStyle(distance >= lowerBound && distance <= upperBound ? Color.green : Color.red)
            }

            // Target line
            RuleMark(y: .value("Target", targetDistance))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(.blue)

            // Lower bound line
            RuleMark(y: .value("Lower Bound", lowerBound))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.gray)

            // Upper bound line
            RuleMark(y: .value("Upper Bound", upperBound))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.gray)
        }
        .chartYAxisLabel("Sweep Distance", position: .leading)
        .chartXAxisLabel("Index", position: .bottom)
        .padding()
    }
}


