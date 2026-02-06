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

/// Represents a single session's sweep data, target, and tolerance
struct SessionData: Identifiable {
    let id = UUID() // Unique identifier for each session
    let sweepDistances: [Float] // Recorded sweep distances for the session
    let targetDistance: Float // Target distance for sweeps
    let tolerance: Float // Tolerance distance

    /// Lower bound for valid sweep distances
    var lowerBound: Float {
        targetDistance - tolerance
    }

    /// Upper bound for valid sweep distances
    var upperBound: Float {
        targetDistance + tolerance
    }
}


class ProfileDataViewController: UIViewController {
  
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    let profileDataView: UIHostingController<ProfileDataView>
    
    init() {
        let selectedProfile = DBInterface.shared.currentProfile
        profileDataView = UIHostingController(rootView: ProfileDataView(studentName: selectedProfile))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder decoder: NSCoder) {
        let selectedProfile = DBInterface.shared.currentProfile
        profileDataView = UIHostingController(rootView: ProfileDataView(studentName: selectedProfile))
        super.init(coder: decoder)
    }
    
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

struct NumberPickerView: View {
    @Binding var selectedNumber: Int
    var maxNumber: Int
    var label: String = "Select a session number"
    
    var body: some View {
        VStack {
            Text(label)
                .font(.headline)
            
            Picker(selection: $selectedNumber, label: Text("")) {
                ForEach(1...maxNumber, id: \.self) { number in
                    Text("\(number)").tag(number)
                }
            }
            .pickerStyle(WheelPickerStyle())
        }
        .padding()
    }
}

class ProfileDataModel: ObservableObject {
    let instructorID: String
    let studentName: String
    @Published var sessionData: [SessionData] = []
    @Published var numSessions: Int = 0
    
    init(instructorID: String, studentName: String) {
        self.instructorID = instructorID
        self.studentName = studentName
    }
    
    func fetchSessions(startDate: Date, endDate: Date) {
        sessionData = []
        FirebaseManager.shared.fetchSessions(user: studentName, instructor: instructorID, startDate: startDate, endDate: endDate) { sessions in
            var convertedSessions: [SessionData] = []
            for session in sessions {
                // TODO: need to store the sweep range
                convertedSessions.append(
                    SessionData(sweepDistances: session.0, targetDistance: session.1, tolerance: session.2)
                )
            }
            DispatchQueue.main.async {
                self.sessionData = convertedSessions
                self.numSessions = convertedSessions.count
            }
        }
    }
}

struct ProfileDataView: View {
    @State private var showingAlert: Bool = false
    @State private var selectedIndex: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @StateObject var dataLoader: ProfileDataModel
    @State private var selectedSession = 1

    
    init(studentName: String) {
        _dataLoader = StateObject(wrappedValue: ProfileDataModel(instructorID: AuthManager.shared.currentUID!, studentName: studentName))
    }
    
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

                    BarPlotView(sessionData: dataLoader.sessionData)
                        .frame(height: 300)
                        .padding()
                } else {
                    // Single Session View with Scatter Plot
                    NumberPickerView(selectedNumber: $selectedSession, maxNumber: dataLoader.numSessions, label: "Select a session number")

                    .padding(.horizontal)

                    Text("Sweep Distances")
                        .font(.headline)
                        .padding(.top)
                    if selectedSession >= 1 && selectedSession <= dataLoader.numSessions {
                        let sessionToGraph = dataLoader.sessionData[selectedSession-1]
                        ScatterPlotView(
                            dataPoints: sessionToGraph.sweepDistances,
                            targetDistance: sessionToGraph.targetDistance,
                            distanceTolerance: sessionToGraph.tolerance
                        )
                        //.frame(height: 300)
                        .padding()
                    } else {
                        Text("No sweeps recorded yet.")
                            .foregroundColor(.gray)
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
            .onChange(of: startDate) { oldValue, newValue in
                let oneDay: TimeInterval = 60 * 60 * 24 // seconds in a day
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: newValue)
                let endOfDay = calendar.startOfDay(for: endDate).addingTimeInterval(TimeInterval(oneDay))
                dataLoader.fetchSessions(startDate: startOfDay, endDate: endOfDay)
            }
            .onChange(of: endDate) { oldValue, newValue in
                let oneDay: TimeInterval = 60 * 60 * 24 // seconds in a day
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: startDate)
                let endOfDay = calendar.startOfDay(for: newValue).addingTimeInterval(TimeInterval(oneDay))
                dataLoader.fetchSessions(startDate: startOfDay, endDate: endOfDay)
            }
            .onAppear() {
                let oneDay: TimeInterval = 60 * 60 * 24 // seconds in a day
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: startDate)
                let endOfDay = calendar.startOfDay(for: endDate).addingTimeInterval(TimeInterval(oneDay))
                dataLoader.fetchSessions(startDate: startOfDay, endDate: endOfDay)
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
    let distanceTolerance: Float

    var body: some View {
        Chart {
            let lowerBound = targetDistance - distanceTolerance
            let upperBound = targetDistance + distanceTolerance
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


