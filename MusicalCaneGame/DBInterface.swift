//
//  DBInterface.swift
//  MusicalCaneGame
//
//  Created by Team Eric on 4/4/19.
//  Copyright © 2019 occamlab. All rights reserved.
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
    let music: Expression<String> = Expression<String>("music")
    
    
    init() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!
        
        do {
            self.db = try Connection("\(path)/cane_game_db.sqlite3")
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
                    t.column(self.music)
            })
                // if there are no rows, add a default user
                let count = try self.db!.scalar(self.users.count)
                if (count == 0) {
                    insertRow(u_name: "Default User", u_sweep_width: 1.0, u_music: "")
                }
            }
        } catch {
            print(error)
        }
        
    }
    
    func insertRow(u_name: String, u_sweep_width: Double, u_music: String) {
        if (db != nil) {
            do {
                let rowId = try self.db!.run(self.users.insert(name <- u_name, sweep_width <- u_sweep_width, music <- u_music))
                print("insertion success! \(rowId)")
                
            } catch {
                print("insertion failed: \(error)")
            }
        }
    }
    
    func getRow(u_name: String) -> Row?{
        if (db != nil) {
            do {
                let rows = try self.db!.prepare(self.users.select(name, sweep_width, music)
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
}




