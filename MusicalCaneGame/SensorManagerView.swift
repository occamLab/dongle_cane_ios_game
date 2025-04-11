import UIKit
import SwiftUI
import MetaWear
import MetaWearCpp
import simd

class SensorManagerViewController: UIViewController, ObservableObject {
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    let sensorManagerView = UIHostingController(rootView: SensorManagerView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        addChildViewController(sensorManagerView)
        sensorManagerView.view.frame = self.view.frame
        self.view.addSubview(sensorManagerView.view)
    }
    
    func sideMenu() {

        if revealViewController() != nil {

            menuButton.target = revealViewController()
            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            revealViewController().rearViewRevealWidth = 250

            view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())

        }
    }
}

struct SensorManagerView: View {
    @ObservedObject var sensorDriver = SensorDriver.shared
    @ObservedObject var witMotionDriver = WITMotion.shared
    @State private var isEditingName = false // Track name editing mode
    @State private var showingSleepAlert = false
    @State private var showingInvalidNameAlert = false
    @State private var showingNameChangeConfirmationAlert = false
    @State private var alertText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if sensorDriver.isBluetoothOn {
                    if !sensorDriver.scannedDevices.isEmpty {
                        List(sensorDriver.scannedDevices, id: \.peripheral.identifier) { device in
                            HStack {
                                if sensorDriver.connectedDevice == device {
                                    // Editable name field for the connected device
                                    if isEditingName {
                                        TextField("Enter new device name", text: $sensorDriver.newDeviceName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .font(.headline)
                                    } else {
                                        Text(sensorDriver.newDeviceName)
                                            .font(.headline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                                                        
                                    // Edit/Confirm button
                                    Button(action: {
                                        if isEditingName {
                                            // Save name change
                                            sensorDriver.changeDeviceName()
                                        }
                                        // Toggle edit mode
                                        isEditingName.toggle()
                                    }) {
                                        Image(systemName: isEditingName ? "checkmark" : "pencil")
                                            .foregroundColor(.blue)
                                            .accessibilityLabel(isEditingName ? "confirm" : "edit name")
                                    }
                                    .padding(.trailing, 10)
                                    
                                    // Sleep Button
                                    Button(action: {
                                        print("showing sleep")
                                        showingSleepAlert = true
                                    }) {
                                        Image(systemName: "moon.fill")
                                            .foregroundColor(.blue)
                                            .accessibilityLabel("Put Sensor to Sleep")
                                    }
                                    Spacer()
                                    
                                    Button("Disconnect") {
                                        sensorDriver.disconnect()
                                        sensorDriver.startScanning()
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                } else {
                                    // Non-editable text for unconnected devices
                                    Text(device.name)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Connect") {
                                        sensorDriver.connect(to: device)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(sensorDriver.connectedDevice != nil || witMotionDriver.connectedDevice != nil) // Disable if another device is connected
                                }
                            }
                            .contentShape(Rectangle()) // Makes the whole HStack tappable
                            .buttonStyle(PlainButtonStyle()) // Avoids interference from default button styling
                        }
                    }
                    // TODO: unify this code (might not be high priority)
                    
                    if sensorDriver.connectedDevice != nil {
                        // Show battery level if a device is connected
                        if let batteryLevel = sensorDriver.batteryLevel {
                            VStack {
                                HStack {
                                    // Battery Level Indicator
                                    VStack {
                                        Text("Battery Level: \(batteryLevel)%")
                                            .font(.headline)
                                            .padding(.top)
                                        ProgressView(value: Float(batteryLevel) / 100.0)
                                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                            .frame(width: 200)
                                    }
                                    .padding()

                                }
                            }
                        }
                    }
                    if !witMotionDriver.scannedDevices.isEmpty {
                        List(witMotionDriver.scannedDevices, id: \.identifier) { device in
                            HStack {
                                if witMotionDriver.connectedDevice?.identifier == device.identifier {
                                    // Editable name field for the connected device
                                    if isEditingName {
                                        TextField("Enter new device name", text: $witMotionDriver.newDeviceName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .font(.headline)
                                    } else {
                                        Text(witMotionDriver.newDeviceName)
                                            .font(.headline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    // Edit/Confirm button
                                    Button(action: {
                                        guard witMotionDriver.newDeviceName.starts(with: "WT") else {
                                            showingInvalidNameAlert = true
                                            alertText = "The name must start with WT"
                                            return
                                        }
                                        guard witMotionDriver.newDeviceName.count <= 16 else {
                                            showingInvalidNameAlert = true
                                            alertText = "The name is limited to 16 characters"
                                            return
                                        }
                                        if isEditingName {
                                            showingNameChangeConfirmationAlert = true
                                            // the name will actually change after the confirmation
                                        } else {
                                            // Toggle edit mode
                                            isEditingName.toggle()
                                        }
                                    }) {
                                        Image(systemName: isEditingName ? "checkmark" : "pencil")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.trailing, 5)
                                    // Sleep Button
                                    Button(action: {
                                        print("showing sleep")
                                        showingSleepAlert = true
                                    }) {
                                        Image(systemName: "moon.fill")
                                            .foregroundColor(.blue)
                                            .accessibilityLabel("Put Sensor to Sleep")
                                    }
                                    Spacer()

                                    Button("Disconnect") {
                                        witMotionDriver.disconnect()
                                        witMotionDriver.startScanning()
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                } else {
                                    // Non-editable text for unconnected devices
                                    Text(device.name ?? "")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Connect") {
                                        witMotionDriver.connect(to: device)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(witMotionDriver.connectedDevice != nil || sensorDriver.connectedDevice != nil) // Disable if another device is connected
                                }
                            }
                            .contentShape(Rectangle()) // Makes the whole HStack tappable
                            .buttonStyle(PlainButtonStyle()) // Avoids interference from default button styling
                        }
                    }
                    if witMotionDriver.connectedDevice != nil {
                        // Show battery level if a device is connected
                        if let batteryLevel = witMotionDriver.batteryLevel {
                            VStack {
                                HStack {
                                    // Battery Level Indicator
                                    VStack {
                                        Text("Battery Level: \(batteryLevel)%")
                                            .font(.headline)
                                            .padding(.top)
                                        ProgressView(value: Float(batteryLevel) / 100.0)
                                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                            .frame(width: 200)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                } else {
                    Text("Bluetooth is off. Please enable Bluetooth to scan for devices.")
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .alert(isPresented: $showingSleepAlert) {
                Alert(
                    title: Text("Put Sensor to Sleep"),
                    message: Text("Putting the sensor to sleep will conserve the sensor's battery. When you want to connect to the sensor again, you will have to press the button on the sensor. Do you want to put the sensor to sleep?"),
                    primaryButton: .destructive(Text("Sleep")) {
                        DispatchQueue.global(qos: .userInitiated).async {
                            if witMotionDriver.connectedDevice != nil {
                                witMotionDriver.putToSleep()
                                witMotionDriver.startScanning()
                            } else if sensorDriver.connectedDevice != nil {
                                sensorDriver.putToSleep()
                                sensorDriver.startScanning()
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(alertText, isPresented: $showingInvalidNameAlert) {
            }
            .alert("The sensor will turn off now.  Press the button on the sensor to turn it on again.  The name change may not be visible until you restart the app.", isPresented: $showingNameChangeConfirmationAlert) {
                Button("OK", role: .cancel) {
                    witMotionDriver.changeDeviceName()
                    isEditingName.toggle()
                    witMotionDriver.startScanning()
                }
            }
            .navigationTitle("Bluetooth Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        sensorDriver.startScanning()
                        witMotionDriver.startScanning()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                    .help("Refresh Device List")
                }
            }
            .overlay {
                if sensorDriver.isConnecting || witMotionDriver.isConnecting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Connecting...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(40)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.8)))
                    }
                }
            }
        }
    }
}
