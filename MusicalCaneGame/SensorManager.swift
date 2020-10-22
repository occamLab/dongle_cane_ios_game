//
//  SensorManager.swift
//  MusicalCaneGame
//
//  TODO: there seems to be a bug with the sleep mode button that can result in the sensor going to sleep and trying to connect simultaneously
//
//  Created by Team Eric on 4/18/19.
//  Copyright © 2019 occamlab. All rights reserved.
//

import Foundation
import CoreBluetooth
import MetaWear
import MBProgressHUD
import iOSDFULibrary
import simd

let updateProgressNotificationKey = "cane.prog.notification"
let connectionStatusChangeRequested = "sensor.connection.changerequested"
let connectionStatusChangeCompleted = "sensor.connection.changecompleted"


class SensorManager: UIViewController {
    private var startSweep = true
    private var startPosition:[Float] = []
    private var device: MBLMetaWear?
    private var finishingConnection = false
    private var streamingEvents: Set<NSObject> = [] // Can't use proper type due to compiler seg fault
    private var stepsPostSensorFusionDataAvailable : (()->())?
    let overflowSize = Float(0.2)
    let underflowSize = Float(0.6)
    let validZoneSize =  Float(0.2)
    var inSweepMode = false
    var isWheelchairUser = false
    var caneLength: Float = 1.0
    var positionAtMaximum: [Float] = []
    var percentTolerance: Float?
    var sweepRange: Float = 1.0
    var sweepTolerance: Float = 20
    var maxDistanceFromStartingThisSweep = Float(-1.0)
    var maxLinearTravel = Float(-1.0)
    var linearTravelThreshold = Float(-1.0)
    var accumulatorSign:Float = 1.0
    var deltaAngle:Float = 0.0 // only applies in wheelchair mode
    var currentAxis:float3?
    var batteryReadTimer:Timer?
    private var prevPosition:[Float] = []
    
    @IBOutlet weak var batteryText: UILabel!
    @IBOutlet weak var putSensorToSleepButton: UIButton!
    @IBOutlet weak var stackViewBar: UIStackView!
    @IBOutlet weak var progressBarUnderflow: UIProgressView!
    @IBOutlet weak var progressBarUI: UIProgressView!
    @IBOutlet weak var progressBarOverflowUI: UIProgressView!
    @IBOutlet weak var progressBarUnderflowSize: NSLayoutConstraint!
    @IBOutlet weak var progressBarSize: NSLayoutConstraint!
    @IBOutlet weak var progressBarOverflowSize: NSLayoutConstraint!
    @IBOutlet weak var sweepRangeText: UILabel!
    @IBOutlet weak var sweepRangeLabel: UILabel!
    @IBOutlet weak var sweepRangeSliderUI: UISlider!
    func euclideanDistance(_ a: Float, _ b: Float) -> Float {
        return (a * a + b * b).squareRoot()
    }

    @IBOutlet weak var batteryLevelIndicator: UIProgressView!
    @IBAction func putSensorToSleep(_ sender: Any) {
        let alert = UIAlertController(title: "Alert", message: "Putting the sensor to sleep will conserve the sensor's battery.  When you want to connect to the sensor again, you will have to press the button on the sensor.  Do you want to put the sensor to sleep?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
              switch action.style{
              case .default:
                self.stopAllStreamingEvents()
                self.inSweepMode = false
                self.device?.sleepModeOnReset()
                self.device?.resetDevice()
                // post a notification that the reset into sleep mode has finished
                NotificationCenter.default.post(name: Notification.Name(rawValue: connectionStatusChangeCompleted), object: false)
              default:
                ()
        }}))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            // do nothing if they cancel
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadProfile()
        createObservers()
        updateProgressView()
        self.batteryLevelIndicator.isHidden = true
        self.batteryText.isHidden = true
        self.putSensorToSleepButton.isEnabled = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func createObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(SensorManager.changeConnectionStatus (notification:)), name: Notification.Name(rawValue: connectionStatusChangeRequested), object: nil)
    }
    
    @objc func changeConnectionStatus(notification: NSNotification) {
        let connect = notification.object as! Bool
        if connect {
            finishConnection(true) { () in
                NotificationCenter.default.post(name: Notification.Name(rawValue: connectionStatusChangeCompleted), object: true)
            }
        } else {
            disconnectAndCleanup()
             { () in
                self.inSweepMode = false
                // post a notification that the disconnection has finished
                NotificationCenter.default.post(name: Notification.Name(rawValue: connectionStatusChangeCompleted), object: false)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        inSweepMode = false
        print("Scanning for the dongle")
        scanForDevice()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disconnectAndCleanup(postDisconnect: nil)
    }

    @IBAction func sweepRange(_ sender: UISlider) {
        let x = Double(sender.value).roundTo(places: 2)
        linearTravelThreshold = Float(x)
        sweepRangeLabel.text = String(x) + " inches"
        sweepRange = sender.value
        updateProgressView()
    }

    /**
    Calculate how full each progress bar should be:
    The progress bars are:
    The one that shows how far under the range they are
    The one that shows where in the range
    The one that shows how far over the range they are

    - Parameter notification: contains the current progress
    */
    func updateProgress(currSweepRange: Float){
        let sweepPercent = currSweepRange/sweepRange
        if( sweepPercent <= (1-percentTolerance!)){
            progressBarUnderflow.progress = sweepPercent/(1-percentTolerance!)
            progressBarUI.progress = 0
            progressBarOverflowUI.progress = 0
        } else if(sweepPercent <= (1+percentTolerance!)){
            progressBarUnderflow.progress = 1
            progressBarUI.progress = (sweepPercent - (1-percentTolerance!))/(2*percentTolerance!)
            progressBarOverflowUI.progress = 0
        } else{
            progressBarUnderflow.progress = 1.0
            progressBarUI.progress = 1.0
            let overflow_percent = (sweepPercent - 1 - percentTolerance!)/overflowSize

            if overflow_percent < 1{
                progressBarOverflowUI.progress = overflow_percent
            } else {
                progressBarOverflowUI.progress = 1
            }
        }
    }
    
    /**
      This function is called when the user switched cane movement directions.
      If the sweep is long enough it will start or continue the music, otherwise
      it will stop the music
      Parameter notification: Passed in container that has the length of the sweep
    */
    @objc func processSweeps(sweepDistance:Float) {
        let name = Notification.Name(rawValue: sweepNotificationKey)
        let is_valid_sweep = (sweepDistance > sweepRange - sweepTolerance) && (sweepDistance < sweepRange + sweepTolerance)
        NotificationCenter.default.post(name: name, object: is_valid_sweep)
    }
    
    /**
    Calculate the size of each progress bar on the screen:
    The progress bars are:
    The one that shows how far under the range they are
    The one that shows where in the range
    The one that shows how far over the range they are
    */
    func updateProgressView(){
        percentTolerance = sweepTolerance/sweepRange
        let totalSize:Float = underflowSize + overflowSize + validZoneSize
        let overflowSizeRel = overflowSize / totalSize

        //----Update Values
        var newConstraint = progressBarUnderflowSize.constraintWithMultiplier(CGFloat(underflowSize))
        self.stackViewBar.removeConstraint(progressBarUnderflowSize)
        progressBarUnderflowSize = newConstraint
        self.stackViewBar.addConstraint(progressBarUnderflowSize)

        newConstraint = progressBarOverflowSize.constraintWithMultiplier(CGFloat(overflowSizeRel))
        self.stackViewBar.removeConstraint(progressBarOverflowSize)
        progressBarOverflowSize = newConstraint
        self.stackViewBar.addConstraint(progressBarOverflowSize)

        newConstraint = progressBarSize.constraintWithMultiplier(CGFloat(validZoneSize))
        self.stackViewBar.removeConstraint(progressBarSize)
        progressBarSize = newConstraint
        self.stackViewBar.addConstraint(progressBarSize)

        self.stackViewBar.layoutIfNeeded()
    }
    
    func loadProfile(){
        //The new method should only use User defaults to know what the current profile is
        if (UserDefaults.standard.string(forKey: "currentProfile") == nil){
            UserDefaults.standard.set("Default User", forKey: "currentProfile")
        }
        let selectedProfile = UserDefaults.standard.string(forKey: "currentProfile")!
        let dbInterface = DBInterface.shared
        let user_row = dbInterface.getRow(u_name: selectedProfile)

        //For the sliders
        sweepRange = Float(user_row![dbInterface.sweep_width])
        caneLength = Float(user_row![dbInterface.cane_length])
        isWheelchairUser = user_row![dbInterface.wheelchair_user]
        linearTravelThreshold = sweepRange    // if we are using wheelchair mode, it's important to set this
        sweepRangeLabel.text = String(Double(sweepRange).roundTo(places: 2)) + " inches"
        sweepRangeSliderUI.setValue(sweepRange, animated: false)
        sweepRangeText.text = isWheelchairUser ? "Activation Distance" : "Sweep Range"
        //For the sliders
        sweepTolerance = Float(user_row![dbInterface.sweep_tolerance])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
                updateProgress(currSweepRange: maxLinearTravel)
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
                updateProgress(currSweepRange: maxDistanceFromStartingThisSweep)

                if deltaDistance < -2.0 { // 2 inches from apex count the sweep
                    // changed
                    processSweeps(sweepDistance: maxDistanceFromStartingThisSweep)
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

    private func stopAllStreamingEvents() {
        for obj in streamingEvents {
            if let event = obj as? MBLEvent<AnyObject> {
                event.stopNotificationsAsync()
            }
        }
        streamingEvents.removeAll()
        putSensorToSleepButton.isEnabled = false
        batteryReadTimer?.invalidate()
        batteryLevelIndicator.isHidden = true
        batteryText.isHidden = true
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
                self.putSensorToSleepButton.isEnabled = true
                // read the battery level if we are connected
                self.batteryReadTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
                    self.device?.readBatteryLifeAsync().success { battery in
                        self.batteryLevelIndicator.progress = Float(battery)/100
                        print("battery: \(battery)")
                        self.batteryLevelIndicator.isHidden = false
                        self.batteryText.isHidden = false
                    }
                }
                self.finishingConnection = false
                return nil
            }
        } else {
            device.disconnectAsync().continueOnDispatch { t in
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
        maxLinearTravel = -1.0
        deltaAngle = 0.0
        currentAxis = nil
        maxDistanceFromStartingThisSweep = -1.0
        var task: BFTask<AnyObject>?
        streamingEvents.insert(device!.sensorFusion!.quaternion)
        // TODO: would be nice if this was executed immediately and then every 60 seconds or so (just need to play with the timers a bit).

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
