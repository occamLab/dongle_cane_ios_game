//
//  SweepDataManager.swift
//  MusicalCaneGame
//
//  Created by occamlab on 12/7/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import FirebaseFirestore

class SweepDataManager {
    /// The singleton instance of this class
    public static var shared = SweepDataManager()
    
    private var collectingSweepData = false
    private var sweepData: Array<Float> = []
    private var sessionStartTime: Timestamp? = nil
    private var fbManager = FirebaseManager.shared
    
    func startDataCollection() {
        self.collectingSweepData = true
        sessionStartTime = Timestamp.init()
    }
    
    func stopAndUploadData() {
        let sessionEndTime = Timestamp.init()
        fbManager.uploadSweepSessionData(sessionStartTime: sessionStartTime!, sessionEndTime: sessionEndTime, sweepData: sweepData)
        
        self.sweepData = []
        self.collectingSweepData = false
        self.sessionStartTime = nil
    }
    
    func addDataPoint(newSweepRange: Float) {
        if self.collectingSweepData {
            sweepData.append(newSweepRange)
        }
    }
}
