//
//  SensorDriver.swift
//  MusicalCaneGame
//
//  Created by occamlab on 11/12/24.
//  Copyright © 2024 occamlab. All rights reserved.
//

import MetaWear
import CoreBluetooth
import RealityKit

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
    
    init() {
        isBluetoothOn = metaWearManager.central.state == .poweredOn
        setupBluetoothStateListener()
    }
    
    func startScanning() {
        scannedDevices.removeAll() // Clear previous scan results
        if let connectedDevice = connectedDevice {
            scannedDevices.append(connectedDevice)
        }
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
    
    func changeDeviceName() {
        guard let device = connectedDevice else { return }
        let name = newDeviceName
        mbl_mw_settings_set_device_name(device.board, name, UInt8(name.count))
        
        print("Device name changed to \(name)")
    }
    
    func putToSleep() {
        guard let device = connectedDevice else { return }
        // Set it to sleep after the next reset
        mbl_mw_debug_enable_power_save(device.board)
        // Preform the soft reset
        mbl_mw_debug_reset(device.board)
        self.connectedDevice = nil
        self.batteryLevel = nil
        print("Device is now in sleep mode.")
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


class WITMotion: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = WITMotion()
    var scanner: CBCentralManager?
    @Published var scannedDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    var commandCharacteristic: CBCharacteristic?
    var sensorUpdateCharacteristic: CBCharacteristic?
    @Published var currentData: simd_quatf?
    @Published var newDeviceName: String = ""
    @Published var batteryLevel: Int? // Store battery level as a percentage
    var batteryTimer: Timer?

    private override init() {
        super.init()
        scanForCompatibleDevices()
    }
    
    func scanForCompatibleDevices() {
        scanner = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Called when Bluetooth status changes
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            print("Bluetooth is not available")
        }
    }

    // Start scanning for BLE devices
    func startScanning() {
        print("Scanning for BLE devices...")
        scanner?.scanForPeripherals(withServices: [CBUUID(string: "0000FFE5-0000-1000-8000-00805F9A34FB")], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    // Called when a device is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered: \(peripheral.name ?? "Unknown Device")")
        
        // Store the peripheral if not already in the list
        if !scannedDevices.contains(peripheral) {
            scannedDevices.append(peripheral)
        }
    }
    
    func changeDeviceName() {
        guard let peripheral = connectedDevice else {
            return
        }
        guard let writeCharacteristic = commandCharacteristic else {
            return
        }
        // See: https://drive.google.com/file/d/1B9DnN8VF9V6bu5-Kj6VurdZEEwGH5m0k/view?usp=drive_link
        // "WT" is the necessary prefix, the device name should have already been validated to start with "WT" and be less than or equal to 16 characters in length
        let packet = "WT" + newDeviceName  + "\r\n"
        let data = Data(packet.utf8)
        peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
    }
    
    func connect(to device: CBPeripheral) {
        device.delegate = self
        scanner?.connect(device, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedDevice {
            scanner?.cancelPeripheralConnection(peripheral)
        }
    }
    
    // Called when connection is successful
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        connectedDevice = peripheral
        newDeviceName = peripheral.name ?? ""
        // Discover services
        peripheral.discoverServices(nil)
    }
    
    // Called if connection fails
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    // Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        for service in peripheral.services ?? [] {
            print("Service found: \(service.uuid)")
            // Discover characteristics for each service
            peripheral.delegate = self
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    private func dataFromHexString(_ hexString: String) -> Data? {
        var data = Data()
        var hex = hexString

        // Ensure the string has an even number of characters
        if hex.count % 2 != 0 {
            return nil
        }

        while !hex.isEmpty {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let byteString = String(hex[..<subIndex])
            hex = String(hex[subIndex...])

            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil // Invalid hex string
            }
        }
        return data
    }
    
    private func writeHexStringToCharacteristic(hexString: String, characteristic: CBCharacteristic, peripheral: CBPeripheral, requestResponse: Bool = false) {
        guard let data = dataFromHexString(hexString) else {
            print("Invalid hex string")
            return
        }

        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) && !requestResponse ? .withoutResponse : .withResponse

        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            print("Characteristic found: \(characteristic.uuid)")

            if characteristic.properties.contains(.write) {
                commandCharacteristic = characteristic
                // unlock config
                writeHexStringToCharacteristic(hexString: "FFAA6988B5", characteristic: characteristic, peripheral: peripheral, requestResponse: true)
                // use 50hz output
                writeHexStringToCharacteristic(hexString: "FFAA030800", characteristic: characteristic, peripheral: peripheral, requestResponse: true)
                // use 10hz output
                // writeHexStringToCharacteristic(hexString: "FFAA030600", characteristic: characteristic, peripheral: peripheral, requestResponse: true)
                // use 6-axis orientation mode (use FFAA240000 for 9-axis) (use FFAA240100 for 6-axis)
                writeHexStringToCharacteristic(hexString: "FFAA240100", characteristic: characteristic, peripheral: peripheral, requestResponse: true)
                writeHexStringToCharacteristic(hexString: "FFAA000000", characteristic: characteristic, peripheral: peripheral, requestResponse: true)

                batteryTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                    print("checking battery level")
                    self.writeHexStringToCharacteristic(hexString: "FFAA276400", characteristic: characteristic, peripheral: peripheral)
                }
            }

            // Subscribe if it's notifiable
            if characteristic.properties.contains(.notify) {
                sensorUpdateCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        guard let value = characteristic.value else {
            return
        }
        // we need a byte array to see which type of packet we are dealing with
        let byteArray = [UInt8](value)
        let parsedValues = dataToSignedShorts(value)
        guard byteArray.count >= 2 else {
            return
        }
        switch byteArray[1] {
        case 0x61:
            if parsedValues.count >= 10 {
                /// See: https://wit-motion.gitbook.io/witmotion-sdk/wit-standard-protocol/wit-standard-communication-protocol
                let angleX = Float(parsedValues[7])/32768.0*Float.pi
                let angleY = Float(parsedValues[8])/32768.0*Float.pi
                let angleZ = Float(parsedValues[9])/32768.0*Float.pi
                // according to WITMotion Python code, the order of the axis consists of fixed rotations around X, Y, and Z (in that order)
                // qua = quaternion_from_euler(angle_radian[0], angle_radian[1], angle_radian[2])
                self.currentData = simd_quatf(angle: angleZ, axis: simd_float3(0, 0, 1)) * simd_quatf(angle: angleY, axis: simd_float3(0, 1, 0)) * simd_quatf(angle: angleX, axis: simd_float3(1, 0, 0))
            }
        case 0x71:
            switch byteArray[2] {
            case 0x64:
                if parsedValues.count >= 3 {
                    let rawBattery = parsedValues[2]
                    // see: https://wit-motion.gitbook.io/witmotion-sdk/ble-5.0-protocol/bluetooth-5.0-communication-protocol#read-power
                    if rawBattery > 396 {
                        batteryLevel = 100
                    } else if rawBattery >= 393 {
                        batteryLevel = 90
                    } else if rawBattery >= 387 {
                        batteryLevel = 75
                    } else if rawBattery >= 382 {
                        batteryLevel = 60
                    } else if rawBattery >= 379 {
                        batteryLevel = 50
                    } else if rawBattery >= 377 {
                        batteryLevel = 40
                    } else if rawBattery >= 373 {
                        batteryLevel = 30
                    } else if rawBattery >= 370 {
                        batteryLevel = 20
                    } else if rawBattery >= 368 {
                        batteryLevel = 15
                    } else if rawBattery >= 350 {
                        batteryLevel = 10
                    } else if rawBattery >= 340 {
                        batteryLevel = 5
                    } else {
                        batteryLevel = 0
                    }
                }
                break
            default:
                break
            }
        default:
            print(value.hexEncodedString())
            break
        }
    }
    
    private func dataToSignedShorts(_ data: Data) -> [Int16] {
        guard data.count % 2 == 0 else {
            fatalError("Data length must be a multiple of 2")
        }

        return data.withUnsafeBytes { rawBuffer in
            let bufferPointer = rawBuffer.bindMemory(to: Int16.self)
            return bufferPointer.map { Int16(littleEndian: $0) }
        }
    }

    func putToSleep() {
        if let device = connectedDevice, let characteristic = commandCharacteristic {
            print("putting board to sleep")
            writeHexStringToCharacteristic(hexString: "FFAA220100", characteristic: characteristic, peripheral: device)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedDevice = nil
        commandCharacteristic = nil
        sensorUpdateCharacteristic = nil
        batteryTimer?.invalidate()
        batteryTimer = nil
        if let error = error {
            print("Error disconnecting: \(error.localizedDescription)")
        } else {
            print("Successfully disconnected from \(peripheral.name ?? "Unknown")")
        }
    }
}
