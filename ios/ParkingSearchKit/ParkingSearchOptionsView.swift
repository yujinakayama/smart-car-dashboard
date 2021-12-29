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
            entranceTimePicker,
            conjunctionLabel,
            timeDurationPicker,
            parkingLabel,
        ])

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 10

        return stackView
    }()

    lazy var entranceDatePicker: RelativeDatePicker = {
        let datePicker = RelativeDatePicker()
        datePicker.dayRangeRelativeToToday = 0...7
        return datePicker
    }()

    lazy var entranceTimePicker = TimePicker()

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

    var entranceDate: Date? {
        guard let baseDate = entranceDatePicker.date,
              let time = entranceTimePicker.time
        else { return nil }

        return baseDate.addingTimeInterval(time.timeIntervalSinceMidnight)
    }

    func setEntranceDate(_ date: Date, animated: Bool) {
        entranceDatePicker.setDate(date, animated: animated)
        entranceTimePicker.setTime(from: date, animated: animated)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        addSubview(stackView)

        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            trailingAnchor.constraint(greaterThanOrEqualTo: stackView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
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
