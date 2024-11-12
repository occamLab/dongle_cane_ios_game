//
//  SensorDriver.swift
//  MusicalCaneGame
//
//  Created by occamlab on 11/12/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import MetaWear
import MetaWearCpp


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
    
    func changeDeviceName() {
        guard let device = connectedDevice else { return }
        let name = newDeviceName
        mbl_mw_settings_set_device_name(device.board, name, UInt8(name.count))
        
        print("Device name changed to \(name)")
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
