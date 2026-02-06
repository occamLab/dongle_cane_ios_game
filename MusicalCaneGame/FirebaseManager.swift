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
    
    private var nameToDocumentID: [String: String] = [:]
    
    private let db: Firestore
    
    var currentUID: String? {
        return authManager.currentUID
    }
    
    private var authManager: AuthManager = AuthManager.shared
    
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
    
    func addUser(name: String, sweep_width: Double, cane_length: Double, music: String, beep_noise: String, music_id: String, sweep_tolerance: Double, wheelchair_user: Bool, stop_immediately: Bool) {
        print("Firebase add user \(name)")

        _ = db.collection("users").addDocument(data: [
            "name": name,
            "sweepWidth": sweep_width,
            "caneLength": cane_length,
            "music": music,
            "beepNoise": beep_noise,
            "musicId": music_id,
            "sweepTolerance": sweep_tolerance,
            "wheelchairUser": wheelchair_user,
            "stopImmediately": stop_immediately,
            "instructorUID": authManager.currentUID!
        ])
    }
    
    func updateUser(name: String, sweep_width: Double, cane_length: Double, music: String, beep_noise: String, music_id: String, sweep_tolerance: Double, wheelchair_user: Bool, stop_immediately: Bool) {
        guard let documentID = nameToDocumentID[name] else {
            return
        }
        print("Firebase updating user")
        _ = db.collection("users").document(documentID).setData([
            "name": name,
            "sweepWidth": sweep_width,
            "caneLength": cane_length,
            "music": music,
            "beepNoise": beep_noise,
            "musicId": music_id,
            "sweepTolerance": sweep_tolerance,
            "wheelchairUser": wheelchair_user,
            "stopImmediately": stop_immediately,
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
                print("Firebase no error \(querySnapshot!.documents.count)")
                for document in querySnapshot!.documents {
                    print("appending")
                    print(document.data())
                    print(document)
                    self.nameToDocumentID[(document.data()["name"] as? String) ?? ""] = document.documentID
                    document_data.append(document.data())
                }
                completion(document_data)
            }
        }
    }
    
    func fetchSessions(user: String,
                       instructor: String,
                       startDate: Date,
                       endDate: Date,
                       completion: @escaping (([([Float], Float, Float)])->())) {
        db.collection("sweepDataTable")
            .whereField("instructorUID", isEqualTo: instructor)
            .whereField("studentName", isEqualTo: user)
            .whereField("sessionEndTime", isGreaterThanOrEqualTo: startDate)
            .whereField("sessionEndTime", isLessThanOrEqualTo: endDate).getDocuments { [self]
            (querySnapshot, error) in
                var allSessions: [([Float], Float, Float)] = []
                if let querySnapshot = querySnapshot {
                    print("found sessions \(querySnapshot.documents.count)")
                    for document in querySnapshot.documents {
                        guard let sweeps = document.data()["sweepData"] as? [Float],
                              let tolerance = document.data()["sweepRange"] as? Float,
                              let range = document.data()["sweepTolerance"] as? Float else {
                            continue
                        }
                        allSessions.append((sweeps, tolerance, range))
                    }
                }
                completion(allSessions)
            print("fetched")
        }
    }
    
    func uploadSweepSessionData(sessionStartTime: Timestamp, sessionEndTime: Timestamp, sweepData: Array<Float>, sweepRange: Float, sweepTolerance: Float) {
        // Note: the session number might be bad to include as it will cost more and more resources to compute as the number of sessions increases.

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
                
                db.collection("sweepDataTable").addDocument(data: [
                    "instructorUID": authManager.currentUID!,
                    "studentName": DBInterface.shared.currentProfile,
                    "sessionStartTime": sessionStartTime,
                    "sessionEndTime": sessionEndTime,
                    "sweepData": sweepData,
                    "sweepRange": sweepRange,
                    "sweepTolerance": sweepTolerance,
                    "sessionNumber": currHighestSessionNumber + 1
                ])
            }
        }
    }
}
