//
//  SteppedAccessibleSlider.swift
//  MusicalCaneGame
//
//  Created by Paul Ruvolo on 2/6/26.
//  Copyright © 2026 occamlab. All rights reserved.
//


class SteppedAccessibleSlider: UISlider {

    var step: Float = 1.0

    override func accessibilityIncrement() {
        let newValue = min(value + step, maximumValue)
        setValue(newValue, animated: true)
        sendActions(for: .valueChanged)
        updateAccessibilityValue()
    }

    override func accessibilityDecrement() {
        let newValue = max(value - step, minimumValue)
        setValue(newValue, animated: true)
        sendActions(for: .valueChanged)
        updateAccessibilityValue()
    }

    private func updateAccessibilityValue() {
        // Customize this to your domain (not just percent)
        accessibilityValue = "\(Double(value).roundTo(places: 1)) inches"
    }
}
