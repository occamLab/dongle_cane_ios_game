//
//  SweepDataManager.swift
//  MusicalCaneGame
//
//  Created by occamlab on 12/7/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

class SweepDataManager {
    /// The singleton instance of this class
    public static var shared = SweepDataManager()
    
    private var collectingSweepData = false
    private var sweepData: Array<Float> = []
    private var sessionStartTime: Date? = nil
    
    func startDataCollection() {
        self.collectingSweepData = true
        sessionStartTime = Date()
    }
    
    func stopAndUploadData() {
        let sessionEndTime = Date()
        let dbInterface = DBInterface.shared
        let selectedProfile = DBInterface.shared.currentProfile
        let user_row = dbInterface.getRow(u_name: selectedProfile)
        let sweepRange = Float(user_row![dbInterface.sweep_width])
        let sweepTolerance = Float(user_row![dbInterface.sweep_tolerance])
        if let sessionStartTime = sessionStartTime  {
            dbInterface.uploadSweepSessionData(sessionStartTime: sessionStartTime, sessionEndTime: sessionEndTime, sweepData: sweepData, sweepRange: sweepRange, sweepTolerance: sweepTolerance)
        }
        
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
