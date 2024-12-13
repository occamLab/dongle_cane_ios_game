//
//  FirebaseManager.swift
//  MusicalCaneGame
//
//  Created by occamlab on 11/5/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import FirebaseFirestore

class FirebaseManager: ObservableObject {
    /// The singleton instance of this class
    public static var shared = FirebaseManager()
    
    private let db: Firestore
    
    private var authManager: AuthManager = AuthManager.shared
    private var dbInterface: DBInterface = DBInterface.shared
    
    private init() {
        db = Firestore.firestore()
    }
    
    func checkOrAppendInstructorUID(instructorUID: String) {
        let docRef = db.collection("instructors").document(instructorUID)
        docRef.getDocument { (documentSnapshot, error) in
            if let error = error {
                print("Error getting document: \(error)")
                return
            }
            
            if let document = documentSnapshot, document.exists {
                print("Document already exists")
            } else {
                // Document does not exist, create it with the provided data
                let data: [String: Any] = ["firstName": "Ayush", "lastName": "Chakraborty", "email": "achakraborty@olin.edu"]
                docRef.setData(data) { err in
                    if let err = err {
                        print("Error creating document: \(err)")
                    } else {
                        print("Document successfully created")
                    }
                }
            }
        }
    }
    
    func addUser(name: String, sweep_width: Double, cane_length: Double, music: String, beep_noise: String, music_id: String, sweep_tolerance: Double, wheelchair_user: Bool) {
        _ = db.collection("users").addDocument(data: [
            "name": name,
            "sweepWidth": sweep_width,
            "caneLength": cane_length,
            "music": music,
            "beepNoise": beep_noise,
            "musicId": music_id,
            "sweepTolerance": sweep_tolerance,
            "wheelchairUser": wheelchair_user,
            "instructorUID": authManager.currentUID!
        ])
    }
    
    func queryUsersForInstructor(completion: @escaping ([[String: Any]]) -> Void) {
        var document_data: Array<[String: Any]> = Array()
        db.collection("users").whereField("instructorUID", isEqualTo: authManager.currentUID!).getDocuments { (querySnapshot, error) in
                    if let error = error {
                        print("Error getting documents: \(error)")
                        completion([])
                    } else {
                        for document in querySnapshot!.documents {
                            document_data.append(document.data())
                        }
                        completion(document_data)
                    }
                }
        completion([])
    }
    
    func uploadSweepSessionData(sessionStartTime: Timestamp, sessionEndTime: Timestamp, sweepData: Array<Float>) {

        // Get the start and end of the current day.
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        db.collection("sweepDataTable").whereField("instructorUID", isEqualTo: authManager.currentUID!).whereField("sessionEndTime", isGreaterThanOrEqualTo: startOfDay).getDocuments { [self]
            (querySnapshot, error) in
            if let error = error {
                print("error getting documents \(error)")
            } else {
                var currHighestSessionNumber: Int = 0
                
                for document in querySnapshot!.documents {
                    let data = document.data()
                    if let sessionNumber = data["sessionNumber"] as? Int {
                        if sessionNumber > currHighestSessionNumber {
                            currHighestSessionNumber = sessionNumber
                        }   
                    }
                }
                
                let user_row = self.dbInterface.getRow(u_name: UserDefaults.standard.string(forKey: "currentProfile")!)
                db.collection("sweepDataTable").addDocument(data: [
                    "instructorUID": authManager.currentUID!,
                    "studentName": UserDefaults.standard.string(forKey: "currentProfile")!,
                    "sessionStartTime": sessionStartTime,
                    "sessionEndTime": sessionEndTime,
                    "sweepData": sweepData,
                    "sessionNumber": currHighestSessionNumber + 1,
                    "sweepTolerance": user_row![self.dbInterface.sweep_tolerance],
                    "sweepTargetDistance": user_row![self.dbInterface.sweep_width]
                ])
            }
        }
    }
    
    func getSessionsForDateRange(startTime: Timestamp, endTime: Timestamp) {
        db.collection("sweepDataTable").whereField("instructorUID", isEqualTo: authManager.currentUID!).whereField("sessionStartTime", isGreaterThanOrEqualTo: startTime).whereField("sessionEndTime", isLessThanOrEqualTo: endTime).whereField("studentName", isEqualTo: UserDefaults.standard.string(forKey: "currentProfile")!).getDocuments {
            (querySnapshot, error) in
            if let error = error {
                print("error getting documents \(error)")
            } else {
                var sessions: Array<SessionData> = []
                for document in querySnapshot!.documents {
                    let data = document.data()
                    sessions.append(SessionData(sweepDistances: data["sweepData"] as! [Float], targetDistance: data["sweepTargetDistance"] as! Float, tolerance: data["sweepTolerance"] as! Float))
                }
                
                completion(sessions)
            }
        }
    }
}
