import UIKit
import SwiftUI

class SensorManagerViewController: UIViewController {
    
    @IBOutlet weak var swiftUIContainer: UIView!
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    let sensorManagerView = UIHostingController(rootView: SensorManagerView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sideMenu()
        addChildViewController(sensorManagerView)
        sensorManagerView.view.frame = swiftUIContainer.bounds
        swiftUIContainer.addSubview(sensorManagerView.view)
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
    @State private var isEditingName = false // Track name editing mode
    
    var body: some View {
        NavigationView {
            VStack {
                if sensorDriver.isBluetoothOn {
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

                                Spacer()

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
                                }
                                .padding(.trailing, 8)
                                Spacer()
                                
                            } else {
                                // Non-editable text for unconnected devices
                                Text(device.name)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Spacer()

                            // Show "Disconnect" button for connected device, otherwise "Connect"
                            if sensorDriver.connectedDevice == device {
                                Button("Disconnect") {
                                    sensorDriver.disconnect()
                                    sensorDriver.startScanning()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            } else {
                                Button("Connect") {
                                    sensorDriver.connect(to: device)
                                }
                                .buttonStyle(.bordered)
                                .disabled(sensorDriver.connectedDevice != nil) // Disable if another device is connected
                            }
                        }
                    }
                    if sensorDriver.connectedDevice != nil {
                        // Show battery level if a device is connected
                        if let batteryLevel = sensorDriver.batteryLevel {
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
                    
                } else {
                    Text("Bluetooth is off. Please enable Bluetooth to scan for devices.")
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Bluetooth Devices")
            .onAppear {
                sensorDriver.startScanning()
            }
            .onDisappear {
                sensorDriver.stopScanning()
            }
            .overlay {
                if sensorDriver.isConnecting {
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
