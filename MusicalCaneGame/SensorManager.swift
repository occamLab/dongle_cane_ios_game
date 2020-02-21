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
    private var startPosition:[Float] = []
    private var device: MBLMetaWear?
    private var finishingConnection = false
    private var streamingEvents: Set<NSObject> = [] // Can't use proper type due to compiler seg fault
    private var stepsPostSensorFusionDataAvailable : (()->())?
    var inSweepMode = false
    var caneLength: Float = 1.0
    var positionAtMaximum: [Float] = []

    var maxDistanceFromStartingThisSweep = Float(-1.0)

    init() {
        
    }
    
    func euclideanDistance(_ a: Float, _ b: Float) -> Float {
        return (a * a + b * b).squareRoot()
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
        let m22 : Float

        // this code is appropriate when the z-axis is aligned with the cane shaft
        if zAxisAlignedWithShaft {
            // x and y projected on z axis from matrix
            m02 = 2.0 * (x*z + y*w) * invs
            m12 = 2.0 * (y*z - x*w) * invs
            m22 = 1 - 2.0 * (x*x - y*y) * invs
        } else {
            // keep name the same even though it is a bit weird
            // x and y projected on x axis from matrix (this is really m01 and m11)
            m02 = 2.0 * (x*y - z*w) * invs
            m12 = 1 - 2.0 * (x*x + z*z) * invs
            m22 = 2.0*(y*z + x*w) * invs
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
            // this should be in inches
            let position = [xPos, yPos]

            // sets first position as a reference point
            if startSweep {
                // use this direction so the progress is relative to the maximum rather than when the sweep was triggered
                if !positionAtMaximum.isEmpty {
                    startPosition = positionAtMaximum
                } else {
                    startPosition = position
                }
                startSweep = false
            }
            
            let distanceFromStarting = euclideanDistance(position[0] - startPosition[0], position[1] - startPosition[1])
            
            // change in distance from maximum
            let deltaDistance = distanceFromStarting - maxDistanceFromStartingThisSweep
            if distanceFromStarting > maxDistanceFromStartingThisSweep {
                maxDistanceFromStartingThisSweep = distanceFromStarting
                positionAtMaximum = position
            }
            
            let name = Notification.Name(rawValue: updateProgressNotificationKey)
            NotificationCenter.default.post(name: name, object: maxDistanceFromStartingThisSweep)
            
            if deltaDistance < -2.0 { // 2 inches from apex count the sweep
                // changed
                let name = Notification.Name(rawValue: sweepNotificationKey)
                NotificationCenter.default.post(name: name, object: maxDistanceFromStartingThisSweep)
                // correct for any offset between the maximum of the sweep and the current position
                startPosition = positionAtMaximum
                maxDistanceFromStartingThisSweep = -1.0
                return
            }
        } else if (length_normalized < 0.2) {
            // Stop music
            print("Shepards Pose")
            let name = Notification.Name(rawValue: sweepNotificationKey)
            maxDistanceFromStartingThisSweep = -1.0
            positionAtMaximum = []
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
        device = nil
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
        guard let device = device else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // in half a second...
                self.finishConnection(on, stepsPostSensorFusionDataAvailable: stepsPostSensorFusionDataAvailable)
            }
            return
        }
        
        if self.finishingConnection {
            // we somehow executed this twice
            return
        }
        self.stepsPostSensorFusionDataAvailable = stepsPostSensorFusionDataAvailable
        MBLMetaWearManager.shared().stopScan()
        finishingConnection = true
        if on {
            device.connect(withTimeoutAsync: 15).continueOnDispatch { t in
                print("CONNECTED!!!!")
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
            device.disconnectAsync().continueOnDispatch { t in
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
