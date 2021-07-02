//
//  ParkingSearchOptionView.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/07/03.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

public class ParkingSearchOptionsView: UIView {
    let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            leftMarginView,
            entranceDatePicker,
            conjunctionLabel,
            timeDurationPicker,
            rightMarginView,
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
        label.font = UIFont.preferredFont(forTextStyle: .title3)
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

    lazy var leftMarginView: UIView = {
        let view = UIView()

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 20),
            view.heightAnchor.constraint(equalTo: view.widthAnchor),
        ])

        return view
    }()

    lazy var rightMarginView: UIView = {
        let view = UIView()

        view.addSubview(activityIndicatorView)
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 20),
            view.heightAnchor.constraint(equalTo: view.widthAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        return view
    }()

    let activityIndicatorView = UIActivityIndicatorView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureSubviews() {
        addSubview(visualEffectView)
        addSubview(stackView)

        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor).withPriority(.defaultLow),
            trailingAnchor.constraint(equalTo: stackView.trailingAnchor).withPriority(.defaultLow),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            layoutMarginsGuide.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
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
