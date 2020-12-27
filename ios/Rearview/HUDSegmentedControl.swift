//
//  HUDSegmentedControl.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/12/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import BetterSegmentedControl

class HUDSegmentedControl: UIControl {
    var titles: [String]?

    var selectedSegmentIndex: Int {
        get {
            segmentedControl.index
        }

        set {
            segmentedControl.setIndex(newValue, animated: true, shouldSendValueChangedEvent: true)
        }
    }

    private let segmentedControl = BetterSegmentedControl()

    init(titles: [String]) {
        self.titles = titles
        super.init(frame: CGRect.zero)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        updateSegments()

        segmentedControl.addTarget(self, action: #selector(segmentedControlDidChangeValue), for: .valueChanged)
        segmentedControl.backgroundColor = UIColor(white: 0.25, alpha: 0.5)

        addSubview(segmentedControl)

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateStyle()
    }

    private func updateStyle() {
        let height = segmentedControl.frame.height
        segmentedControl.cornerRadius = height / 2
        segmentedControl.indicatorViewInset = round(height * 0.06 * UIScreen.main.scale) / UIScreen.main.scale

        let index = selectedSegmentIndex
        updateSegments()
        segmentedControl.setIndex(index, animated: false, shouldSendValueChangedEvent: false)
    }

    private func updateSegments() {
        let fontSize: CGFloat = segmentedControl.frame.height * 0.35

        segmentedControl.segments = LabelSegment.segments(
            withTitles: titles ?? [],
            normalFont: .systemFont(ofSize: fontSize, weight: .medium),
            normalTextColor: UIColor(white: 1, alpha: 0.75),
            selectedFont: .systemFont(ofSize: fontSize, weight: .bold),
            selectedTextColor: UIColor(white: 0, alpha: 0.7)
        )
    }

    @IBAction private func segmentedControlDidChangeValue() {
        sendActions(for: .valueChanged)
    }
}
