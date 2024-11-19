//
//  SensorDriver.swift
//  MusicalCaneGame
//
//  Created by occamlab on 11/12/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import MetaWear
import MetaWearCpp
import simd

class SensorDriver: ObservableObject {
    static let shared = SensorDriver()
    @Published var scannedDevices: [MetaWear] = []
    @Published var isBluetoothOn = false
    @Published var connectedDevice: MetaWear?
    @Published var isConnecting = false
    @Published var batteryLevel: Int? // Store battery level as a percentage
    @Published var newDeviceName: String = ""
    private let metaWearManager = MetaWearScanner.shared
    var batteryTimer: OpaquePointer?
    
    // Attributes for the sensor fusion
    var startSweep = true
    var startPosition:[Float] = []
    private var stepsPostSensorFusionDataAvailable : (()->())?
    let overflowSize = Float(0.2)
    let underflowSize = Float(0.6)
    let validZoneSize =  Float(0.2)
    var inSweepMode = false
    var isWheelchairUser = false
    var caneLength: Float = 1.0
    var positionAtMaximum: [Float] = []
    var percentTolerance: Float? = 0.2
    @Published var sweepRange: Float = 1.0
    @Published var sweepTolerance: Float = 20
    var maxDistanceFromStartingThisSweep = Float(-1.0)
    var maxLinearTravel = Float(-1.0)
    var linearTravelThreshold = Float(-1.0)
    var accumulatorSign:Float = 1.0
    var deltaAngle:Float = 0.0 // only applies in wheelchair mode
    var currentAxis:float3?
    @Published var underflowProgress: Float = 0.0
    @Published var validZoneProgress: Float = 0.0
    @Published var overflowProgress: Float = 0.0
    var prevPosition:[Float] = []
    
    init() {
        isBluetoothOn = metaWearManager.central.state == .poweredOn
        setupBluetoothStateListener()
    }
    
    func startScanning() {
        scannedDevices.removeAll() // Clear previous scan results
        
        // Only start scanning if Bluetooth is on
        if isBluetoothOn {
            isBluetoothOn = true
            metaWearManager.startScan(allowDuplicates: true) { [weak self] device in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if !self.scannedDevices.contains(where: { $0.peripheral.identifier == device.peripheral.identifier }) {
                        self.scannedDevices.append(device)
                    }
                }
            }
        }
    }
    
    func stopScanning() {
        metaWearManager.stopScan()
    }
    
    private func setupBluetoothStateListener() {
        // Listen for Bluetooth state changes via MetaWearScanner's `didUpdateState` callback
        metaWearManager.didUpdateState = { [weak self] central in
            DispatchQueue.main.async {
                self?.isBluetoothOn = (central.state == .poweredOn)
                if self?.isBluetoothOn == true {
                    print("Bluetooth is on, starting scan...")
                    self?.startScanning()
                } else {
                    print("Bluetooth is off, stopping scan.")
                    self?.isConnecting = false
                    self?.stopBatteryReadings()
                    self?.connectedDevice = nil
                    self?.stopScanning()
                    self?.scannedDevices.removeAll() // Clear devices if Bluetooth is off
                }
            }
        }
    }
    
    func connect(to device: MetaWear) {
        stopScanning()
        
        DispatchQueue.main.async {
            self.isConnecting = true
        }
        
        device.connectAndSetup().continueWith { task in
            DispatchQueue.main.async {
                self.isConnecting = false
                
                if let error = task.error {
                    print("Failed to connect to device: \(error.localizedDescription)")
                } else {
                    self.connectedDevice = device
                    self.newDeviceName = device.name
                    print("Connected to \(device.name)")
                    
                    var pattern = MblMwLedPattern()
                    mbl_mw_led_load_preset_pattern(&pattern, MBL_MW_LED_PRESET_PULSE)
                    mbl_mw_led_stop_and_clear(device.board)
                    pattern.repeat_count = 5
                    mbl_mw_led_write_pattern(device.board, &pattern, MBL_MW_LED_COLOR_GREEN)
                    mbl_mw_led_play(device.board)
                    
                    self.scheduleBatteryReadings() // Start reading battery level
//                    self.startQuaternionStreaming()
                }
            }
        }
    }
    
    func disconnect() {
        guard let device = connectedDevice else { return }
        
        mbl_mw_led_stop_and_clear(device.board)
        device.cancelConnection()
        
        DispatchQueue.main.async {
            self.connectedDevice = nil
            self.batteryLevel = nil
            print("Disconnected from \(device.name)")
        }
        
        stopBatteryReadings() // Stop battery readings when disconnected
    }
    
    private func scheduleBatteryReadings() {
        guard let device = connectedDevice else { return }
        let signal = mbl_mw_settings_get_battery_state_data_signal(device.board)!
        mbl_mw_datasignal_subscribe(signal, bridge(obj: self), batteryStateCallback)

        // Create a timer to read battery level every 30000ms
        mbl_mw_timer_create_indefinite(device.board, 30000, 0, bridge(obj: self), batteryTimerCreatedCallback)
    }
    
    func handleBatteryReadTimer(timer: OpaquePointer) {
        guard let device = connectedDevice else { return }
        let signal = mbl_mw_settings_get_battery_state_data_signal(device.board)!
        mbl_mw_event_record_commands(timer)
        mbl_mw_datasignal_read(signal)
        mbl_mw_event_end_record(timer, bridge(obj: self), eventEndCallback)
    }
    
    private func stopBatteryReadings() {
        guard let timer = batteryTimer else { return }
        
        mbl_mw_timer_remove(timer) // Stop the timer on the MetaWear device
        batteryTimer = nil
    }
    
    func startQuaternionStreaming() {
        guard let device = connectedDevice else { return }
        let signal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION)!
        mbl_mw_datasignal_subscribe(signal, bridge(obj: self), processSensorFusion)
        mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
        mbl_mw_sensor_fusion_set_mode(device.board, MBL_MW_SENSOR_FUSION_MODE_IMU_PLUS)
        mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION)
        mbl_mw_sensor_fusion_write_config(device.board)
        mbl_mw_sensor_fusion_start(device.board)
    }
    
    func stopQuaternionStreaming() {
        guard let device = connectedDevice else { return }
        mbl_mw_sensor_fusion_stop(device.board)
        mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
        let signal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION)!
        mbl_mw_datasignal_unsubscribe(signal)
    }
    
    func changeDeviceName() {
        guard let device = connectedDevice else { return }
        let name = newDeviceName
        mbl_mw_settings_set_device_name(device.board, name, UInt8(name.count))
        
        print("Device name changed to \(name)")
    }
    
    func updateProgress(currSweepRange: Float) {
        let sweepPercent = currSweepRange / sweepRange

        DispatchQueue.main.async {
            if sweepPercent <= (1 - self.percentTolerance!) {
                self.underflowProgress = sweepPercent / (1 - self.percentTolerance!)
                self.validZoneProgress = 0
                self.overflowProgress = 0
            } else if sweepPercent <= (1 + self.percentTolerance!) {
                self.underflowProgress = 1
                self.validZoneProgress = (sweepPercent - (1 - self.percentTolerance!)) / (2 * self.percentTolerance!)
                self.overflowProgress = 0
            } else {
                self.underflowProgress = 1.0
                self.validZoneProgress = 1.0
                let overflowPercent = (sweepPercent - 1 - self.percentTolerance!) / self.overflowSize

                if overflowPercent < 1 {
                    self.overflowProgress = overflowPercent
                } else {
                    self.overflowProgress = 1
                }
            }
            print("Progress Updated: Underflow: \(self.underflowProgress), Valid Zone: \(self.validZoneProgress), Overflow: \(self.overflowProgress)")
        }
    }
}

func batteryStateCallback(context: UnsafeMutableRawPointer?, data: UnsafePointer<MblMwData>?) {
    guard let context = context, let data = data else { return }
    let manager = bridge(ptr: context) as SensorDriver
    let batteryState: MblMwBatteryState = data.pointee.valueAs()
    DispatchQueue.main.async {
        manager.batteryLevel = Int(batteryState.charge)
    }
    print("Battery Level: \(batteryState.charge)%")
}

func batteryTimerCreatedCallback(context: UnsafeMutableRawPointer?, timer: OpaquePointer?) {
    guard let context = context, let timer = timer else { return }
    let manager = bridge(ptr: context) as SensorDriver
    manager.batteryTimer = timer
    manager.handleBatteryReadTimer(timer: timer)
}

func eventEndCallback(context: UnsafeMutableRawPointer?, timer: OpaquePointer?, status: Int32) {
    if status == 0 {
        mbl_mw_timer_start(timer)
    } else {
        print("Failed to end event recording with status: \(status)")
    }
}

func processSensorFusion(context: UnsafeMutableRawPointer?, data: UnsafePointer<MblMwData>?) {
    guard let context = context, let data = data else { return }
    let manager = bridge(ptr: context) as SensorDriver
    let quaternion: MblMwQuaternion = data.pointee.valueAs()
    let x = Float(quaternion.x)
    let y = Float(quaternion.y)
    let z = Float(quaternion.z)
    let w = Float(quaternion.w)
    let caneLength = manager.caneLength
    let isWheelchairUser = manager.isWheelchairUser
    let linearTravelThreshold = manager.linearTravelThreshold
    var startSweep = manager.startSweep
    var startPosition = manager.startPosition
    var prevPosition = manager.prevPosition
    var positionAtMaximum = manager.positionAtMaximum
    var maxDistanceFromStartingThisSweep = manager.maxDistanceFromStartingThisSweep
    var maxLinearTravel = manager.maxLinearTravel
    var accumulatorSign = manager.accumulatorSign
    var deltaAngle = manager.deltaAngle
    var currentAxis = manager.currentAxis
    
    // Rotation Matrix
    // math from euclideanspace (https://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToMatrix/index.htm)
    // for normalization
    let invs = 1 / (x*x + y*y + z*z + w*w)
    // x and y projected on z axis from matrix
    let m02 : Float
    let m12 : Float
    let m22 : Float

    // keep name the same even though it is a bit weird
    // x and y projected on x-axis from matrix (this is really m00 and m10)
    // Break down the computation for m02
    let yy = y * y
    let zz = z * z
    let twoYYZZ = 2.0 * (yy + zz)
    m02 = 1 - (twoYYZZ * invs)

    // Break down the computation for m12
    let xy = x * y
    let zw = z * w
    let twoXYPlusZW = 2.0 * (xy + zw)
    m12 = twoXYPlusZW * invs

    // Break down the computation for m22
    let xz = x * z
    let yw = y * w
    let twoXZMinusYW = 2.0 * (xz - yw)
    m22 = twoXZMinusYW * invs
    
//    print("m02 \(m02) m12 \(m12) m22 \(m22)")
    // normalized vector values multiplied by cane length
    // to estimate tip of cane
    let xPos = m02 * caneLength
    let yPos = m12 * caneLength
    let zPos = m22 * caneLength

    if xPos.isNaN || yPos.isNaN || (xPos == 0 && yPos == 0) {
        return
    }

    let lengthOnZAxiz = sqrt((xPos * xPos) + (yPos * yPos))
    let length_normalized = lengthOnZAxiz / caneLength

    if length_normalized > 0.3 || isWheelchairUser {        // the Shepard's pose doesn't matter if you are a wheelchair user
        // this should be in inches
        let position = [xPos, yPos, zPos]

        // sets first position as a reference point
        if startSweep {
            // use this direction so the progress is relative to the maximum rather than when the sweep was triggered
            if !positionAtMaximum.isEmpty {
                startPosition = positionAtMaximum
            } else {
                startPosition = position
            }
            if prevPosition.isEmpty {
                prevPosition = startPosition
            }
            startSweep = false
        }

        if isWheelchairUser {
            // get cross product
            var dp = simd_dot(float3(position), float3(prevPosition))/(simd_length(float3(position))*simd_length(float3(prevPosition)))
            if dp < -1 {
                dp = -1
            } else if dp > 1 {
                dp = 1
            }
            // get the unsigned (always positive) angle between
            let angleBetween = acos(dp)
            // get the axis perpendicular to the plane spanned by the two vectors
            let cp = cross(float3(position), float3(prevPosition))
            if let axis = currentAxis {
                if simd_dot(axis, cp) < 0 {         // the axis has switched
                    currentAxis = cp
                    accumulatorSign *= -1
                }
            } else {
                // initialize the axis
                currentAxis = cp
            }
            deltaAngle += angleBetween*accumulatorSign
            prevPosition = position
            let linearTravel = abs(caneLength*deltaAngle)
            if linearTravel > maxLinearTravel {
                positionAtMaximum = position
                maxLinearTravel = linearTravel
            }
            manager.updateProgress(currSweepRange: maxLinearTravel)
            if maxLinearTravel > linearTravelThreshold {
                // changed
                let name = Notification.Name(rawValue: sweepNotificationKey)
                NotificationCenter.default.post(name: name, object: true)
                // correct for any offset between the maximum of the sweep and the current position
                startPosition = positionAtMaximum
                prevPosition = startPosition
                maxLinearTravel = -1.0
                deltaAngle = 0.0
                currentAxis = nil
                return
            }
        } else {
            let distanceFromStarting = euclideanDistance(position[0] - startPosition[0], position[1] - startPosition[1])

            // change in distance from maximum
            let deltaDistance = distanceFromStarting - maxDistanceFromStartingThisSweep
            if distanceFromStarting > maxDistanceFromStartingThisSweep {
                maxDistanceFromStartingThisSweep = distanceFromStarting
                positionAtMaximum = position
            }
            manager.updateProgress(currSweepRange: maxDistanceFromStartingThisSweep)

            if deltaDistance < -2.0 { // 2 inches from apex count the sweep
                // changed
//                    processSweeps(sweepDistance: maxDistanceFromStartingThisSweep)
                print("finalDistance", maxDistanceFromStartingThisSweep)
                // correct for any offset between the maximum of the sweep and the current position
                startPosition = positionAtMaximum
                maxDistanceFromStartingThisSweep = -1.0
                return
            }
        }
    } else if (length_normalized < 0.2) {
        // record a bad sweep due to shepherd's pose
        let name = Notification.Name(rawValue: sweepNotificationKey)
        maxDistanceFromStartingThisSweep = -1.0
        positionAtMaximum = []
        NotificationCenter.default.post(name: name, object:  false)
    }
}

func euclideanDistance(_ a: Float, _ b: Float) -> Float {
    return (a * a + b * b).squareRoot()
}
