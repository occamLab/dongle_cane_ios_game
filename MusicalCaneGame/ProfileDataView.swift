//
//  ProfileDataView.swift
//  MusicalCaneGame
//
//  Created by occamlab on 12/3/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import UIKit
import SwiftUI

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
    @State private var selectedIndex: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selectedIndex) {
                    Text("History").tag(0)
                    Text("Single Session").tag(1)
                }
                .pickerStyle(.segmented)
                
                if selectedIndex == 0 {
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
                } else {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                }
            }
            .navigationTitle("Progress Tracking Data")
        }
    }
}

//#Preview {
//    ProfileDataView()
//}
