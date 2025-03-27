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
    let resolver = BWT901BLE5_0ProtocolResolver()
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
        // TODO
        print("No support for this so far, but is definitely possible... \(newDeviceName)")
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
    
    private func writeHexStringToCharacteristic(hexString: String, characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        guard let data = dataFromHexString(hexString) else {
            print("Invalid hex string")
            return
        }

        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

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
                // use 50hz output
                writeHexStringToCharacteristic(hexString: "FFAA030800", characteristic: characteristic, peripheral: peripheral)
                // use 6-axis orientation mode (use FFAA240000 for 9-axis) (use FFAA240100 for 6-axis)
                writeHexStringToCharacteristic(hexString: "FFAA240100", characteristic: characteristic, peripheral: peripheral)
                batteryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
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


class BWT901BLE5_0ProtocolResolver {
    
    var angleX: Float?
    var angleY: Float?
    var angleZ: Float?
    
    // 要解析的数据
    var activeByteDataBuffer:[UInt8] = [UInt8]()
    
    // 临时Byte
    var activeByteTemp:[UInt8] = [UInt8]()
    
    /**
     * 查找传感器返回的值
     *
     * @author huangyajun
     * @date 2022/5/23 14:17
     */
    func findReturnData(_ returnData:[UInt8]) -> [UInt8]? {
        var temp:[UInt8]
        if let index55 = returnData.firstIndex(of: 0x55){
            if index55 + 1 < returnData.count, returnData[index55 + 1] == 0x71{
                temp = Array(returnData[index55...])
                return Array(temp.prefix(20))
            }
        }
        return nil;
    }
    
    
    // 解算实时数据
    func passiveReceiveData(data: [UInt8]) {
        
        if (data.count < 1) {
            return;
        }
        
        
        activeByteDataBuffer.append(contentsOf: data)
        
        // 移除非法数据
        while (activeByteDataBuffer.count > 0
               && activeByteDataBuffer[0] != 0x55
               && (activeByteDataBuffer[1] != 0x61 || activeByteDataBuffer[1] != 0x71)) {
            activeByteDataBuffer.remove(at: 0)
        }
        
        while (activeByteDataBuffer.count >= 20) {
            activeByteTemp = activeByteDataBuffer[0..<20].reversed()
            activeByteDataBuffer = activeByteDataBuffer[20..<activeByteDataBuffer.count].reversed()
            
            // 必须是55 61的数据包
            if (activeByteTemp[0] == 0x55 && activeByteTemp[1] == 0x61) {
                var fData:[Int16] = [Int16](repeating: 0, count: 9)
                var i:Int = 0
                while (i < 9) {
                    
                    let h:Int16 = Int16(activeByteTemp[i * 2 + 3])
                    let l:Int16 = Int16(activeByteTemp[i * 2 + 2])
                    fData[i] = Int16(h << 8 | l & 0xff)
                    let Identify:String = String(format: "%2X",activeByteTemp[1])
                    switch i {
                    case 6:
                        angleX = Float(fData[i])/32768*180
                    case 7:
                        angleY = Float(fData[i])/32768*180
                    case 8:
                        angleZ = Float(fData[i])/32768*180
                    default:
                        break
                    }
                    i = i+1
                }
            }
            else if(activeByteTemp[0] == 0x55 && activeByteTemp[1] == 0x71){
                let readReg:Int = Int(activeByteTemp[3]) << 8 | Int(activeByteTemp[2])
                var Pack:[Int16] = [Int16](repeating: 0, count: 4)
                var i = 0
                while (i < 4) {
                    Pack[i] = Int16(activeByteTemp[5 + (i*2)]) << 8 | Int16(activeByteTemp[4 + (i*2)])
                    var reg:String = String(format: "%02X",readReg + i).uppercased()
                    reg = StringUtils.padLeft(reg, 2, "0")
                    i = i+1
                }
            }
        }
        print(angleX, angleY, angleZ)
    }
}


class StringUtils {
    
    // 判断是空串
    static func IsNullOrEmpty(_ str:String?) -> Bool{
        return str == nil || str == ""
    }
    
    // 判断不是空串
    static func IsNotNullOrEmpty(_ str:String?) -> Bool{
        return str != nil && str != ""
    }
    
    // 左边补齐
    static func padLeft(_ str:String,_ len:Int,_ char:String) -> String {
        
        if(str.count >= len){
            return str
        }

        
        let count = str.count
        var i = 0
        var append = ""
        
        while(i < len - count){
            append.append(contentsOf: char)
            i = i + 1
        }
        
        return append + str
    }
    
    // 右边补齐
    static func padRight(_ str:String,_ len:Int,_ char:String) -> String {
        
        if(str.count >= len){
            return str
        }

        var i = 0
        var append = ""
        while(i<len - str.count){
            append.append(contentsOf: char)
            i = i + 1
        }
        
        return  str + append
    }
    
    // 获得子字符串
    static func subString(_ str:String,_ start:Int,_ len:Int) -> String {
        let index = str.index(str.startIndex, offsetBy: start)
        let endIndex = str.index(str.startIndex, offsetBy: start + len)
        return String(str[index..<endIndex])
    }
}
