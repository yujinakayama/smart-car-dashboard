//
//  ParkingSearchOptionView.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/07/03.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

public class ParkingSearchOptionsView: UIView {
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            entranceDatePicker,
            conjunctionLabel,
            timeDurationPicker,
            parkingLabel,
        ])

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing

        return stackView
    }()

    lazy var entranceDatePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .time
        datePicker.minuteInterval = 10
        datePicker.preferredDatePickerStyle = .inline
        datePicker.locale = Locale(identifier: "en_GB")
        return datePicker
    }()

    lazy var conjunctionLabel = makeLabel(text: "から")

    lazy var timeDurationPicker: TimeDurationPicker = {
        let timeDurationPicker = TimeDurationPicker()

        timeDurationPicker.durations = [
            30,
            60,
            120,
            180,
            360,
            720,
            1080,
            1440
        ].map { TimeInterval($0 * 60) }

        timeDurationPicker.selectRow(1, animated: false)

        return timeDurationPicker
    }()

    lazy var parkingLabel = makeLabel(text: "駐車")

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40)
        ])

        addSubview(stackView)

        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            trailingAnchor.constraint(greaterThanOrEqualTo: stackView.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        for subview in stackView.arrangedSubviews {
            subview.setContentHuggingPriority(.required, for: .horizontal)
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateShadow()
        }
    }

    private func updateShadow() {
        if traitCollection.userInterfaceStyle == .dark {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.15
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.05
        }
    }

    private func makeLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        return label
    }
}
