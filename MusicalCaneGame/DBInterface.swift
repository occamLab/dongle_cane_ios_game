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
    var db
    var name
    var sweep_width
    var music
    var users
    
    func create_db() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!

        db = try Connection("\(path)/cane_game_db.sqlite3")

        // Users table
        users = Table("users")

        //Column names
        name = Expression<String>("name")
        sweep_width = Expression<Double>("sweep_width")
        music = Expression<String>("music")

        // create the table if it doesn't exist
        try db.run(users.create(ifNotExists: true) { t in
            t.column(name, primaryKey: true)
            t.column(sweep_width)
            t.column(music)
        })
    }
}




