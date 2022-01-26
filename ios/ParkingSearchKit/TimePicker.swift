//
//  TimePicker.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/09/29.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

@IBDesignable class TimePicker: UIControl, UIPickerViewDataSource, UIPickerViewDelegate {
    var time: Time? {
        let selectedRow = pickerView.selectedRow(inComponent: 0)
        guard selectedRow >= 0 else { return nil }
        return time(for: selectedRow)
    }

    private var previousTime: Time?

    var minuteInterval: Int = 30 {
        didSet {
            updateTimes()
        }
    }

    private var times: [Time] = []

    private lazy var pickerView: UIPickerView = {
        let pickerView = UIPickerView()
        pickerView.dataSource = self
        pickerView.delegate = self
        return pickerView
    }()

    private var heightConstraint: NSLayoutConstraint?

    private let pickerViewBuiltInHorizontalPadding: CGFloat = 9 // Left and right each

    private lazy var fontMetrics = UIFontMetrics(forTextStyle: .body)
    private lazy var font = UIFont.preferredFont(forTextStyle: .body)

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    private func commonInit() {
        clipsToBounds = true

        addSubview(pickerView)

        pickerView.translatesAutoresizingMaskIntoConstraints = false

        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        updateHeightConstraint()

        NSLayoutConstraint.activate([
            heightConstraint!,
            pickerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            pickerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -pickerViewBuiltInHorizontalPadding),
            trailingAnchor.constraint(equalTo: pickerView.trailingAnchor, constant: -pickerViewBuiltInHorizontalPadding),
        ])

        updateTimes()

        setTime(from: Date(), animated: false)
    }

    private func updateTimes(additionalTime: Time? = nil) {
        times = Array(stride(from: Time.min, to: Time.max, by: TimeInterval(minuteInterval * 60)))

        if let additionalTime = additionalTime, !times.contains(additionalTime) {
            times.append(additionalTime)
            times.sort()
        }

        pickerView.reloadAllComponents()
    }

    private func format(_ time: Time) -> String {
        return String(format: "%02d:%02d", time.hour, time.minute)
    }

    private func updateHeightConstraint() {
        guard let heightConstraint = heightConstraint else { return }
        heightConstraint.constant = rowHeight + 2
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: maxLabelWidth + 20, height: heightConstraint?.constant ?? 0)
    }

    private var maxLabelWidth: CGFloat {
        let label = makeLabel()

        let widths: [CGFloat] = times.map { (time) in
            label.text = format(time)
            label.sizeToFit()
            return label.frame.width
        }

        return widths.max() ?? 0
    }

    func setTime(from date: Date, animated: Bool) {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        let timeInterval = TimeInterval(components.hour! * 3600 + components.minute! * 60)
        let time = Time(timeIntervalSinceMidnight: timeInterval)
        setTime(time, animated: animated)
    }

    func setTime(_ time: Time, animated: Bool) {
        updateTimes(additionalTime: time)
        let index = times.lastIndex(where: { $0 <= time }) ?? 0
        pickerView.selectRow(times.count + index, inComponent: 0, animated: animated)
        previousTime = time
    }

    func time(for row: Int) -> Time {
        let index = row % times.count
        return times[index]
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return times.count * 3
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? makeLabel()
        label.text = format(time(for: row))
        return label
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return rowHeight
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if time != previousTime {
            sendActions(for: .valueChanged)
        }

        previousTime = time

        reselectMiddleRowForCurrentTime()
    }

    private func reselectMiddleRowForCurrentTime() {
        let index = pickerView.selectedRow(inComponent: 0) % times.count
        pickerView.selectRow(times.count + index, inComponent: 0, animated: false)
    }

    private var rowHeight: CGFloat {
        return fontMetrics.scaledValue(for: 33)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateHeightConstraint()
        pickerView.setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    private func makeLabel() -> UILabel {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = font
        label.textAlignment = .center
        return label
    }
}

extension TimePicker {
    struct Time: Strideable {
        typealias Stride = TimeInterval

        static let min = Time(timeIntervalSinceMidnight: 0)
        static let max = Time(timeIntervalSinceMidnight: 60 * 60 * 24)

        var timeIntervalSinceMidnight: TimeInterval

        var hour: Int {
            return Int(timeIntervalSinceMidnight / 3600)
        }

        var minute: Int {
            return Int(timeIntervalSinceMidnight) % 3600 / 60
        }

        var second: Int {
            return Int(timeIntervalSinceMidnight) % 3600 % 60
        }

        func advanced(by n: Stride) -> Self {
            return Self(timeIntervalSinceMidnight: timeIntervalSinceMidnight + n)
        }

        func distance(to other: Self) -> Stride {
            return other.timeIntervalSinceMidnight - timeIntervalSinceMidnight
        }
    }
}
