//
//  SensorManager.swift
//  MusicalCaneGame
//
//  Created by Team Eric on 4/18/19.
//  Copyright © 2019 occamlab. All rights reserved.
//

import Foundation
import CoreBluetooth
import MetaWear
import MBProgressHUD
import iOSDFULibrary

class SensorManager {
    private var startSweep = true
    private var startDir:[Float] = []
    private var anglePrev:Float = 0.0
    private var device: MBLMetaWear?
    private var finishingConnection = false
    private var streamingEvents: Set<NSObject> = [] // Can't use proper type due to compiler seg fault
    private var stepsPostSensorFusionDataAvailable : (()->())?
    var inSweepMode = false
    var caneLength: Float = 1.0
    var directionAtMaximum = [Float(1.0), Float(0.0)]
    var maxAngleFromStartingThisSweep = Float(-1.0)
    
    init() {
        
    }

    public func sensorFusionReadingNewDongle(w: Float, x: Float, y: Float, z: Float, caneLength: Float) {
        // Rotation Matrix
        // math from euclideanspace (https://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToMatrix/index.htm)
        // for normalization
        let invs = 1 / (x*x + y*y + z*z + w*w)
        let zAxisAlignedWithShaft = false
        // x and y projected on z axis from matrix
        let m02 : Float
        let m12 : Float
        
        // this code is appropriate when the z-axis is aligned with the cane shaft
        if zAxisAlignedWithShaft {
            // x and y projected on z axis from matrix
            m02 = 2.0 * (x*z + y*w) * invs
            m12 = 2.0 * (y*z - x*w) * invs
        } else {
            // keep name the same even though it is a bit weird
            // x and y projected on x axis from matrix (this is really m01 and m11)
            m02 = 2.0 * (x*y - z*w) * invs
            m12 = 1 - 2.0 * (x*x + z*z) * invs
        }
        // normalized vector values multiplied by cane length
        // to estimate tip of cane
        let xPos = m02 * caneLength
        let yPos = m12 * caneLength
        
        if xPos.isNaN || yPos.isNaN || (xPos == 0 && yPos == 0) {
            return
        }
        
        let lengthOnZAxiz = sqrt((xPos * xPos) + (yPos * yPos))
        let length_normalized = lengthOnZAxiz / caneLength
        
        if length_normalized > 0.3 {
            
            // normalizing
            var direction = [xPos, yPos]
            let magnitude = lengthOnZAxiz
            direction = direction.map { $0 / magnitude }
            
            // sets first position as direction as a reference point
            if startSweep {
                // use this direction so the progress is relative to the maximum rather than when the sweep was triggered
                startDir = directionAtMaximum
                startSweep = false
            }
            
            // using dot product to find angle between starting vector and current direction
            // varified
            let angleFromStarting = acos(direction[0] * startDir[0] + direction[1] * startDir[1])
            
            // change in angle
            let deltaAngle = angleFromStarting - anglePrev
            print("anglefrom starting", angleFromStarting, "maxanglefromstaring", maxAngleFromStartingThisSweep)
            if angleFromStarting > maxAngleFromStartingThisSweep {
                maxAngleFromStartingThisSweep = angleFromStarting
                directionAtMaximum = direction
                print(maxAngleFromStartingThisSweep)
            }
            
            // change in angle from radians to degrees
            let deltaAngleDeg = deltaAngle * 57.2958
            let sweepDistance = caneLength * sin(maxAngleFromStartingThisSweep / 2) * 2
            //            sweepProgress.setProgress(sweepDistance/sweepRange, animated: false)
            let name = Notification.Name(rawValue: updateProgressNotificationKey)
            NotificationCenter.default.post(name: name, object: sweepDistance)
            
            if deltaAngleDeg < -0.5 {
                // changed
                let name = Notification.Name(rawValue: sweepNotificationKey)
                NotificationCenter.default.post(name: name, object: sweepDistance)
                
                startDir = direction
                // correct for any offset between the maximum of the sweep and the current angle
                anglePrev = 0.0
                maxAngleFromStartingThisSweep = -1.0
                return
            }
            anglePrev = angleFromStarting
        } else if (length_normalized < 0.2) {
            // Stop music
            print("Shepards Pose")
            let name = Notification.Name(rawValue: sweepNotificationKey)
            maxAngleFromStartingThisSweep = -1.0
            NotificationCenter.default.post(name: name, object:  -10)
        }
    }

    private func stopAllStreamingEvents() {
        for obj in streamingEvents {
            if let event = obj as? MBLEvent<AnyObject> {
                event.stopNotificationsAsync()
            }
        }
        streamingEvents.removeAll()
    }

    func scanForDevice() {
        finishingConnection = false
        MBLMetaWearManager.shared().startScan(forMetaWearsAllowDuplicates: true, handler: { array in
            if !self.finishingConnection {
                self.device = array[0]
            }
        })
    }

    func disconnectAndCleanup(postDisconnect: (() -> Void)?) {
        stopAllStreamingEvents()
        device?.disconnectAsync().continueOnDispatch {_ in
            postDisconnect?()
        }
    }
    
    func finishConnection(_ on: Bool, stepsPostSensorFusionDataAvailable: @escaping ()->()) {
        if self.finishingConnection {
            // we somehow executed this twice
            return
        }
        self.stepsPostSensorFusionDataAvailable = stepsPostSensorFusionDataAvailable
        MBLMetaWearManager.shared().stopScan()
        finishingConnection = true
        if on {
            device?.connect(withTimeoutAsync: 15).continueOnDispatch { t in
                if (t.error?._domain == kMBLErrorDomain) && (t.error?._code == kMBLErrorOutdatedFirmware) {
                    return nil
                }
                if t.error != nil {
                    print("ERROR CONNECTING")
                } else {
                    print("DEVICE CONNECTED")
                    self.sensorFusionStartStreamPressed()
                }
                self.finishingConnection = false
                return nil
            }
        } else {
            device?.disconnectAsync().continueOnDispatch { t in
                //self.deviceDisconnected()
                if t.error != nil {
                    print(t.error!.localizedDescription)
                }
                return nil
            }
        }
    }
    
    func updateSensorFusionSettings() {
        device?.sensorFusion?.mode = MBLSensorFusionMode(rawValue:2)! // this is probably IMU+ (verify this) https://mbientlab.com/iosdocs/2/sensor_fusion.html
    }

    func sensorFusionStartStreamPressed() {
        updateSensorFusionSettings()
        
        var task: BFTask<AnyObject>?
        
        streamingEvents.insert(device!.sensorFusion!.quaternion)
        task = device!.sensorFusion!.quaternion.startNotificationsAsync { (obj, error) in
            if let obj = obj {
                if !self.inSweepMode {
                    self.stepsPostSensorFusionDataAvailable?()
                    self.inSweepMode = true
                }
                self.sensorFusionReadingNewDongle(w: Float(obj.w), x: Float(obj.x), y: Float(obj.y), z: Float(obj.z), caneLength: self.caneLength)
            }
        }
    }
}
