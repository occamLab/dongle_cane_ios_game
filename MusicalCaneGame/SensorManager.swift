//
//  SensorManager.swift
//  MusicalCaneGame
//
//  Created by Team Eric on 4/18/19.
//  Copyright © 2019 occamlab. All rights reserved.
//

import Foundation
import CoreBluetooth

// test

class SensorManager {
    var startSweep = true
    var startDir:[Float] = []
    var anglePrev:Float = 0.0
    
    init() {
        
    }
    
    public func sensorFusionReading(from characteristic: CBCharacteristic, caneLength: Float) {
        guard let characteristicData = characteristic.value else { return }
        let byteArray = [UInt8](characteristicData)
        let data = Data(bytes: byteArray[3...])
        
        let array = data.withUnsafeBytes {
            [Int16](UnsafeBufferPointer(start: $0, count: 4))
        }
        
        // get quaternion vales from the dongle
        let w = Float(array[0]) / Float(Int16.max)
        let x = Float(array[1]) / Float(Int16.max)
        let y = Float(array[2]) / Float(Int16.max)
        let z = Float(array[3]) / Float(Int16.max)
        
        
        // Rotation Matrix
        // math from euclideanspace
        // for normalization
        let invs = 1 / (x*x + y*y + z*z + w*w)
        
        // x and y projected on z axis from matrix
        let m02 = 2.0 * (x*z + y*w) * invs
        let m12 = 2.0 * (y*z - x*w) * invs
        
        // normaized vector values multiplied by cane length
        // to estimate tip of cane
        let xPos = m02 * caneLength
        let yPos = m12 * caneLength
        
        if xPos.isNaN || yPos.isNaN || (xPos == 0 && yPos == 0) {
            return
        }
        
        let lengthOnZAxiz = sqrt((xPos * xPos) + (yPos * yPos))
        let length_normalized = lengthOnZAxiz / caneLength
        print("Length of Z: \(length_normalized)")
        
        if length_normalized > 0.3 {
            
            // normalizing
            var direction = [xPos, yPos]
            let magnitude = lengthOnZAxiz
            direction = direction.map { $0 / magnitude }
            
            // sets frist position as direction as a reference point
            if startSweep == true {
                startDir = direction
                startSweep = false
            }
            
            // using dot product to find angle between starting vector and current direction
            // varified
            let angleFromStarting = acos(direction[0] * startDir[0] + direction[1] * startDir[1])
            
            // change in angle
            let deltaAngle = angleFromStarting - anglePrev
            
            // change in angle from raidans to degrees
            let deltaAngleDeg = deltaAngle * 57.2958
            let sweepDistance = caneLength * sin(angleFromStarting / 2) * 2
            //            sweepProgress.setProgress(sweepDistance/sweepRange, animated: false)
            let name = Notification.Name(rawValue: updateProgressNotificationKey)
            NotificationCenter.default.post(name: name, object: sweepDistance)
            
            if deltaAngleDeg > 1.0 || deltaAngleDeg < -1.0 {
                if deltaAngle < 0 {
                    
                    // changed
                    let name = Notification.Name(rawValue: sweepNotificationKey)
                    NotificationCenter.default.post(name: name, object: sweepDistance)
                    
                    startDir = direction
                    anglePrev = 0.0
                    return
                }
            }
            anglePrev = angleFromStarting
        } else if (length_normalized < 0.2) {
            // Stop music
            print("Shepards Pose")
            let name = Notification.Name(rawValue: sweepNotificationKey)
            NotificationCenter.default.post(name: name, object:  -10)
        }
        return
    }
}
