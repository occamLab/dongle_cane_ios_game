/**
DBInterface.swift
MusicalCaneGame
Created by Team Eric on 4/4/19.
Copyright © 2019 occamlab. All rights reserved.
Built off of the SQLite.swift library.
For more information, documentation is here:
https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md
*/

import Foundation
import SQLite

/**
DB class to store user profiles. Uses SQLite Pod.
Run pod install if this class breaks.
*/
class DBInterface {
    static let shared = DBInterface()
    
    /// Database
    var db: Connection?
    /// Users table
    let users: Table = Table("Users")
    
    // Properties of Beacons that are set for all users
    let beaconIds: Table = Table("beaconIds")
    
    /// user beacon mappings table
    let beaconMappings: Table = Table("BeaconMappings")

    /// column names
    let name: Expression<String> = Expression<String>("name")
    let sweep_width: Expression<Double> = Expression<Double>("sweep_width")
    let cane_length: Expression<Double> = Expression<Double>("cane_length")
    let music: Expression<String> = Expression<String>("music")
    let beep_noise: Expression<String> = Expression<String>("beep_noise")
    let music_id: Expression<String> = Expression<String>("music_id")
    let sweep_tolerance: Expression<Double> = Expression<Double>("sweep_tolerance")
    let wheelchair_user: Expression<Bool> = Expression<Bool>("wheelchair_user")
    let beacons_enabled: Expression<Bool> = Expression<Bool>("beacons_enabled")

    // column names for beacon Ids
    let beaconMinor: Expression<Int> = Expression<Int>("beaconminor")
    let beaconName: Expression<String> = Expression<String>("beaconname")
    let beaconColorHexCode: Expression<String> = Expression<String>("beaconcolorhexcode")


    /// column names for beacon mappings
    let locationText: Expression<String> = Expression<String>("locationtext")
    let voiceNoteURL: Expression<String> = Expression<String>("voicenoteurl")
    let beaconStatus: Expression<Int> = Expression<Int>("beaconstatus")
    
    private init() {
        
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!
        
        
        do {
            self.db = try Connection("\(path)/cane_game_db_v2.sqlite3")
        } catch {
            print(error)
            return
        }
        
        do {
            if (db != nil) {
                 //dropTable()
                // create the table if it doesn't exist
                try self.db!.run(self.users.create(ifNotExists: true) { t in
                    t.column(self.name, primaryKey: true)
                    t.column(self.sweep_width)
                    t.column(self.cane_length)
                    t.column(self.music)
                    t.column(self.beep_noise)
                    t.column(self.music_id)
                    t.column(self.sweep_tolerance)
                    t.column(self.beacons_enabled)
                    t.column(self.wheelchair_user)
            })
                // if there are no rows, add a default user
                let count = try self.db!.scalar(self.users.count)
                print(count)
                if (count == 0) {
                    insertRow(u_name: "Default User", u_sweep_width: 20, u_cane_length: 40, u_music: "Select Music", u_beep_noise: "Begin Record", u_music_id: "", u_sweep_tolerance: 15, u_wheelchair_user: false)
                }
                try self.db!.run(self.beaconMappings.create(ifNotExists: true) { t in
                    t.column(self.name)
                    t.column(self.beaconMinor)
                    t.column(self.locationText)
                    t.column(self.voiceNoteURL)
                    t.column(self.beaconStatus          )
                })
                try self.db!.run(self.beaconIds.create(ifNotExists: true) { t in
                    t.column(self.beaconMinor)
                    t.column(self.beaconName)
                    t.column(self.beaconColorHexCode)
                })
            } else {
                print("error loading database")
            }
        } catch {
            print(error)
        }
        
    }
    
    func insertRow(u_name: String, u_sweep_width: Double, u_cane_length: Double, u_music: String, u_beep_noise: String, u_music_id: String, u_sweep_tolerance: Double, u_wheelchair_user: Bool) {
        if (db != nil) {
            do {
                let rowId = try self.db!.run(self.users.insert(name <- u_name, sweep_width <- u_sweep_width, cane_length <- u_cane_length, music <- u_music, beep_noise <- u_beep_noise, music_id <- u_music_id, sweep_tolerance <- u_sweep_tolerance, beacons_enabled <- false, wheelchair_user <- u_wheelchair_user))
                print("insertion success! \(rowId)")
                
            } catch {
                print("insertion failed: \(error)")
            }
        }
    }
    
    func getRow(u_name: String) -> Row?{
        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.users.select(name, sweep_width, cane_length, music, beep_noise, music_id, sweep_tolerance, beacons_enabled, wheelchair_user)
                                                .filter(name == u_name))
                for row in rows {
                    return row
                }
            } catch {
                print("select failed: \(error)")
            }
        }else{
            print("DB NIL")
        }
        return nil
    }
    
    func getBeaconNames(u_name: String, b_minor: Int) -> Row?{
        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.beaconMappings.select(name, beaconMinor, locationText, voiceNoteURL, beaconStatus).filter(name == u_name && b_minor == beaconMinor))
                for row in rows {
                    return row
                }
            } catch {
                print("select failed: \(error)")
            }
        }else{
            print("DB NIL")
        }
        return nil
    }
    
    func getBeaconMinors() -> [Int]{
        var minors: [Int] = []

        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.beaconIds.select(beaconMinor, beaconName))
                for row in rows {
                    minors.append(row[beaconMinor])
                }
            } catch {
                print("select failed: \(error)")
            }
        }else{
            print("DB NIL")
        }
        return minors
    }
    
    
    func getGlobalBeaconName(b_minor: Int) -> String?{
        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.beaconIds.select(beaconMinor, beaconName).filter(beaconMinor == b_minor))
                for row in rows {
                    return row[beaconName]
                }
            } catch {
                print("select failed: \(error)")
            }
        }else{
            print("DB NIL")
        }
        return nil
    }
    
    func getGlobalBeaconColorHexCode(b_minor: Int) -> String?{
        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.beaconIds.select(beaconMinor, beaconColorHexCode).filter(beaconMinor == b_minor))
                for row in rows {
                    return row[beaconColorHexCode]
                }
            } catch {
                print("select failed: \(error)")
            }
        }else{
            print("DB NIL")
        }
        return nil
    }
    
    
    func updateGlobalBeaconName(b_minor: Int, b_name: String) {
        do {
            if getGlobalBeaconName(b_minor: b_minor) == nil {
                print("inserting new entry")
                try self.db!.run(self.beaconIds.insert(beaconMinor <- b_minor, beaconName <- b_name, beaconColorHexCode <- "#FFFFFF"))
            } else {
                try self.db!.run(self.beaconIds.filter(beaconMinor == b_minor)
                    .update(beaconName <- b_name))
            }
        } catch {
            print("error updating beacon Ids table: \(error)")
        }
    }
    
    
    func updateGlobalBeaconColorHexCode(b_minor: Int, b_hex_code: String) {
        do {
            if getGlobalBeaconName(b_minor: b_minor) == nil {
                print("inserting new entry")
                try self.db!.run(self.beaconIds.insert(beaconMinor <- b_minor, beaconName <- "Unknown", beaconColorHexCode <- b_hex_code))
            } else {
                try self.db!.run(self.beaconIds.filter(beaconMinor == b_minor)
                    .update(beaconColorHexCode <- b_hex_code))
            }
        } catch {
            print("error updating beacon Ids table: \(error)")
        }
    }
    
    
    func forgetBeacon(b_minor: Int) {
        do {
            try self.db!.run(self.beaconIds.filter(beaconMinor == b_minor).delete())
        } catch {
            print("error updating beacon Ids table: \(error)")
        }
    }
    
    
    func updateBeaconLocation(u_name: String, b_minor: Int, location_text: String) {
        // Update just the location of the Beacon
        do {
            insertBeaconDataRowIfMissing(u_name: u_name, b_minor: b_minor)
            try self.db!.run(self.beaconMappings.filter(name == u_name && beaconMinor == b_minor)
                    .update(locationText <- location_text))
        } catch {
            print("error updating beacon table: \(error)")
        }
    }
    
    func updateBeaconStatus(u_name: String, b_minor: Int, status: Int) {
        // Update just the location of the Beacon
        do {
            insertBeaconDataRowIfMissing(u_name: u_name, b_minor: b_minor)
            try self.db!.run(self.beaconMappings.filter(name == u_name && beaconMinor == b_minor)
                    .update(beaconStatus <- status))
        } catch {
            print("error updating beacon table: \(error)")
        }
    }
    
    func insertBeaconDataRowIfMissing(u_name: String, b_minor: Int) {
        do {
           if getBeaconNames(u_name: u_name, b_minor: b_minor) == nil {
               print("inserting new entry")
               try self.db!.run(self.beaconMappings.insert(name <- u_name, beaconMinor <- b_minor, locationText <- "", voiceNoteURL <- "", beaconStatus <- 0))
           }
       } catch {
           print("error updating beacon table: \(error)")
       }
    }
    
    func updateBeaconVoiceNote(u_name: String, b_minor: Int, voiceNote_URL: String) {
        // Update all values
        do {
            insertBeaconDataRowIfMissing(u_name: u_name, b_minor: b_minor)
            try self.db!.run(self.beaconMappings.filter(name == u_name && beaconMinor == b_minor)
                    .update(voiceNoteURL <- voiceNote_URL))
        } catch {
            print("error updating beacon table: \(error)")
        }
    }
    
    func updateBeaconsEnabled(u_name: String, enabled: Bool) {
        do {
            try self.db!.run(self.users.filter(name == u_name)
                .update(beacons_enabled <- enabled))
        } catch {
            print("error updating users table: \(error)")
        }
    }
    
    func updateRow(u_name: String, u_sweep_width: Double, u_cane_length: Double, u_music: String, u_beep_noise: String, u_music_id: String, u_sweep_tolerance: Double, u_wheelchair_user: Bool) {
        // Update all values except the Beacon enabled flag
        do {
            try self.db!.run(self.users.filter(name == u_name)
                .update(sweep_width <- u_sweep_width,
                        cane_length <- u_cane_length, music <- u_music, beep_noise <- u_beep_noise, music_id <- u_music_id, sweep_tolerance <- u_sweep_tolerance, wheelchair_user <- u_wheelchair_user))
        } catch {
            print("error updating users table: \(error)")
        }
    }
    
    func dropTable() {
        do {
            try self.db!.run(self.users.drop())
            try self.db!.run(self.beaconMappings.drop())
        } catch {
            print("error dropping users table: \(error)")
        }
    }
    
    func getAllUserNames() -> [String] {
        var names: [String] = []
        do {
            let rows = try self.db!.prepare(self.users)
            for row in rows {
                names.append(row[name])
            }
        } catch {
            print("error in getting user names: \(error)")
        }
        return names
    }
}




