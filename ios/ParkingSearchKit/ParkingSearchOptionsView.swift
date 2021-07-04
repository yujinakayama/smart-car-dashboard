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
        ])

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill

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

    lazy var conjunctionLabel: UILabel = {
        let label = UILabel()
        label.text = "から"
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        return label
    }()

    lazy var timeDurationPicker: TimeDurationPicker = {
        let timeDurationPicker = TimeDurationPicker()

        timeDurationPicker.durations = [
            30,
            60,
            120,
            180,
            360,
            720,
            1440
        ].map { TimeInterval($0 * 60) }

        timeDurationPicker.selectRow(1, animated: false)

        timeDurationPicker.setContentHuggingPriority(.required, for: .horizontal)
        timeDurationPicker.setContentHuggingPriority(.required, for: .vertical)

        return timeDurationPicker
    }()

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
            heightAnchor.constraint(equalToConstant: 37)
        ])

        addSubview(stackView)

        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor).withPriority(.defaultLow),
            trailingAnchor.constraint(equalTo: stackView.trailingAnchor).withPriority(.defaultLow),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
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
}
