//
//  SteppedAccessibleSlider.swift
//  MusicalCaneGame
//
//  Created by Paul Ruvolo on 2/6/26.
//  Copyright © 2026 occamlab. All rights reserved.
//


class SteppedAccessibleSlider: UISlider {

    var step: Float = 1.0
    
    
    private func commonInit() {
        // run once on creation
        updateAccessibilityValue()

        // if you want to ensure updates when the user drags:
        addTarget(self, action: #selector(onValueChanged), for: .valueChanged)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override var value: Float {
        didSet { updateAccessibilityValue() }
    }
    
    @objc private func onValueChanged() {
        updateAccessibilityValue()
    }

    override func accessibilityIncrement() {
        let newValue = min(value + step, maximumValue)
        setValue(newValue, animated: true)
        sendActions(for: .valueChanged)
    }

    override func accessibilityDecrement() {
        let newValue = max(value - step, minimumValue)
        setValue(newValue, animated: true)
        sendActions(for: .valueChanged)
    }

    private func updateAccessibilityValue() {
        // Customize this to your domain (not just percent)
        accessibilityValue = "\(Double(value).roundTo(places: 1)) inches"
    }
}
