//
//  RelativeDatePicker.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/09/26.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

@IBDesignable class RelativeDatePicker: UIControl, UIPickerViewDataSource, UIPickerViewDelegate {
    var date: Date? {
        let selectedRow = pickerView.selectedRow(inComponent: 0)
        guard selectedRow <= dates.count - 1 else { return nil }
        return dates[selectedRow]
    }

    var dayRangeRelativeToToday: ClosedRange<Int> = 0...0 {
        didSet {
            updateDates()
        }
    }

    private var dates: [Date] = []

    private var today = Date()

    private lazy var pickerView: UIPickerView = {
        let pickerView = UIPickerView()
        pickerView.dataSource = self
        pickerView.delegate = self
        return pickerView
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.formattingContext = .listItem
        formatter.setLocalizedDateFormatFromTemplate("MdE")
        return formatter
    }()

    // doesRelativeDateFormatting and setLocalizedDateFormatFromTemplate cannot be used at same time :(
    private lazy var relativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        formatter.formattingContext = .listItem
        return formatter
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

        updateDates()

        setDate(today, animated: false)

        NotificationCenter.default.addObserver(self, selector: #selector(updateDates), name: UIApplication.significantTimeChangeNotification, object: nil)
    }

    @objc private func updateDates() {
        let previouslySelectedDate = date

        let calendar = Calendar.autoupdatingCurrent

        today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!

        dates = dayRangeRelativeToToday.map { (dayDelta) in
            return calendar.date(byAdding: .day, value: dayDelta, to: today)!
        }

        pickerView.reloadAllComponents()

        if let previouslySelectedDate = previouslySelectedDate {
            setDate(previouslySelectedDate, animated: false)
        }
    }

    private func format(_ date: Date) -> String {
        if abs(date.timeIntervalSince(today)) <= 60 * 60 * 24 + 1 {
            return relativeDateFormatter.string(from: date)
        } else {
            return dateFormatter.string(from: date)
        }
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

        let widths: [CGFloat] = dates.map { (date) in
            label.text = format(date)
            label.sizeToFit()
            return label.frame.width
        }

        return widths.max() ?? 0
    }

    func setDate(_ date: Date, animated: Bool) {
        guard let targetDate = Calendar.autoupdatingCurrent.date(bySettingHour: 0, minute: 0, second: 0, of: date) else { return }
        guard let row = dates.firstIndex(of: targetDate) else { return }
        selectRow(row, animated: animated)
    }

    func selectRow(_ row: Int, animated: Bool) {
        pickerView.selectRow(row, inComponent: 0, animated: animated)
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dates.count
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? makeLabel()
        label.text = format(dates[row])
        return label
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return rowHeight
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        sendActions(for: .valueChanged)
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
