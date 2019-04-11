//
//  DBInterface.swift
//  MusicalCaneGame
//
//  Created by Team Eric on 4/4/19.
//  Copyright © 2019 occamlab. All rights reserved.
//
// Built off of the SQLite.swift library.
// For more information, documentation is here:
// https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md
//

import Foundation
import SQLite

class DBInterface {
    // Database
    var db: Connection?
    // Users table
    let users: Table = Table("Users")
    // column names
    let name: Expression<String> = Expression<String>("name")
    let sweep_width: Expression<Double> = Expression<Double>("sweep_width")
    let cane_length: Expression<Double> = Expression<Double>("cane_length")
    let beep_count: Expression<Int> = Expression<Int>("beep_count")
    let music: Expression<String> = Expression<String>("music")
    
    
    init() {
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
                // create the table if it doesn't exist
                try self.db!.run(self.users.create(ifNotExists: true) { t in
                    t.column(self.name, primaryKey: true)
                    t.column(self.sweep_width)
                    t.column(self.cane_length)
                    t.column(self.beep_count)
                    t.column(self.music)
            })
                // if there are no rows, add a default user
                let count = try self.db!.scalar(self.users.count)
                if (count == 0) {
                    insertRow(u_name: "Default User", u_sweep_width: 1.0, u_cane_length: 1.0, u_beep_count: 20, u_music: "")
                }
            }
        } catch {
            print(error)
        }
        
    }
    
    func insertRow(u_name: String, u_sweep_width: Double, u_cane_length: Double , u_beep_count: Int,u_music: String) {
        if (db != nil) {
            do {
                let rowId = try self.db!.run(self.users.insert(name <- u_name, sweep_width <- u_sweep_width, cane_length <- u_cane_length, beep_count <- u_beep_count,music <- u_music))
                print("insertion success! \(rowId)")
                
            } catch {
                print("insertion failed: \(error)")
            }
        }
    }
    
    func getRow(u_name: String) -> Row?{
        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.users.select(name, sweep_width, cane_length, beep_count, music)
                                                .filter(name == u_name))
                for row in rows {
                    return row
                }
            } catch {
                print("select failed: \(error)")
            }
        }
        return nil
    }
    
    func getMusic(u_name: String) -> URL?{
        return URL(string: getRow(u_name: u_name)![music])
    }
    
    func getSweepWidth(u_name: String) -> Double? {
        return getRow(u_name: u_name)![sweep_width]
    }
    
    func getCaneLength(u_name: String) -> Double? {
        return getRow(u_name: u_name)![cane_length]
    }
    
    func getBeepCount(u_name: String) -> Int? {
        return getRow(u_name: u_name)![beep_count]
    }
    
    func changeMusic(u_name: String, u_music: String) {
        do {
            try self.db!.run(self.users.filter(name == u_name).update(music <- u_music))
        } catch {
            print("update failed: \(error)")
        }
    }
    
    func changeSweepWidth(u_name: String, u_sweep_width: Double) {
        do {
            try self.db!.run(self.users.filter(name == u_name).update(sweep_width <- u_sweep_width))
        } catch {
            print("update failed: \(error)")
        }
    }
    
    func updateRow(u_name: String, u_sweep_width: Double, u_cane_length: Double , u_beep_count: Int,u_music: String) {
        // Update all values
        do {
            try self.db!.run(self.users.filter(name == u_name)
                .update(sweep_width <- u_sweep_width,
                        cane_length <- u_cane_length,
                        beep_count <- u_beep_count,
                        music <- u_music))
        } catch {
            
        }
    }
    
    func dropTable() {
        do {
            try self.db!.run(self.users.drop())
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




