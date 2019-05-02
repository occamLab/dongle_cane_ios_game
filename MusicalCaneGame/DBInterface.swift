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
    let beep_noise: Expression<String> = Expression<String>("beep_noise")
    let music_url: Expression<String> = Expression<String>("music_url")
    let sweep_tolerance: Expression<Double> = Expression<Double>("sweep_tolerance")
    
    
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
//                dropTable()
                // create the table if it doesn't exist
                try self.db!.run(self.users.create(ifNotExists: true) { t in
                    t.column(self.name, primaryKey: true)
                    t.column(self.sweep_width)
                    t.column(self.cane_length)
                    t.column(self.beep_count)
                    t.column(self.music)
                    t.column(self.beep_noise)
                    t.column(self.music_url)
                    t.column(self.sweep_tolerance)
            })
                // if there are no rows, add a default user
                let count = try self.db!.scalar(self.users.count)
                print(count)
                if (count == 0) {
                    insertRow(u_name: "Default User", u_sweep_width: 1.0, u_cane_length: 1.0, u_beep_count: 20, u_music: "Select Music", u_beep_noise: "Select Beep", u_music_url: "", u_sweep_tolerance: 20)
                }
            } else {
                print("error loading database")
            }
        } catch {
            print(error)
        }
        
    }
    
    func insertRow(u_name: String, u_sweep_width: Double, u_cane_length: Double , u_beep_count: Int,u_music: String, u_beep_noise: String, u_music_url: String, u_sweep_tolerance: Double) {
        if (db != nil) {
            do {
                let rowId = try self.db!.run(self.users.insert(name <- u_name, sweep_width <- u_sweep_width, cane_length <- u_cane_length, beep_count <- u_beep_count,music <- u_music, beep_noise <- u_beep_noise, music_url <- u_music_url, sweep_tolerance <- u_sweep_tolerance))
                print("insertion success! \(rowId)")
                
            } catch {
                print("insertion failed: \(error)")
            }
        }
    }
    
    func getRow(u_name: String) -> Row?{
        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.users.select(name, sweep_width, cane_length, beep_count, music, beep_noise, music_url, sweep_tolerance)
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
    
    func updateRow(u_name: String, u_sweep_width: Double, u_cane_length: Double, u_beep_count: Int,u_music: String, u_beep_noise: String, u_music_url: String, u_sweep_tolerance: Double) {
        // Update all values
        do {
            try self.db!.run(self.users.filter(name == u_name)
                .update(sweep_width <- u_sweep_width,
                        cane_length <- u_cane_length, beep_count <- u_beep_count, music <- u_music, beep_noise <- u_beep_noise, music_url <- u_music_url, sweep_tolerance <- u_sweep_tolerance))
        } catch {
            print("error updating users table: \(error)")
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




