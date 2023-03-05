//
//  ETCUsageTableViewCell.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/04.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCPaymentTableViewCell: UITableViewCell {
    static var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter
    }()

    static var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    @IBOutlet weak var yenLabel: UILabel!
    @IBOutlet weak var amountView: UIView!
    @IBOutlet weak var amountLabel: UILabel!

    @IBOutlet weak var entranceTimeLabel: UILabel!
    @IBOutlet weak var timeArrowView: UIImageView!
    @IBOutlet weak var exitTimeLabel: UILabel!

    @IBOutlet weak var entranceRoadLabel: UILabel!
    @IBOutlet weak var entranceTollboothLabel: UILabel!
    @IBOutlet weak var tollboothArrowView: UIImageView!
    @IBOutlet weak var exitRoadLabel: UILabel!
    @IBOutlet weak var exitTollboothLabel: UILabel!

    var payment: ETCPayment! {
        didSet {
            updateViews()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        var font: UIFont

        if let avenirNext = UIFont(name: "AvenirNext-Bold", size: 17) {
            let fontMetrics = UIFontMetrics(forTextStyle: .headline)
            font = fontMetrics.scaledFont(for: avenirNext)
        } else {
            font = UIFont.preferredFont(forTextStyle: .headline)
        }

        [yenLabel, amountLabel].forEach { (label) in
            label!.font = font
            label!.adjustsFontForContentSizeCategory = true
        }
    }

    private func updateViews() {
        amountLabel.text = Self.numberFormatter.string(from: NSNumber(value: payment.amount))

        exitTimeLabel.text = Self.dateFormatter.string(from: payment.exitDate)

        if let entranceDate = payment.entranceDate {
            entranceTimeLabel.isHidden = false
            entranceTimeLabel.text = Self.dateFormatter.string(from: entranceDate)
            timeArrowView.isHidden = false
        } else {
            entranceTimeLabel.isHidden = true
            timeArrowView.isHidden = true
        }

        let entrance = payment.entranceTollbooth
        let exit = payment.exitTollbooth

        if let entrance = entrance {
            entranceRoadLabel.isHidden = false
            entranceRoadLabel.text = entrance.road.abbreviatedName
            entranceTollboothLabel.text = entrance.name
        } else {
            entranceRoadLabel.isHidden = true
            entranceTollboothLabel.text = String(localized: "Unknown Tollbooth")
        }

        if let exit = exit {
            if exit == entrance {
                tollboothArrowView.isHidden = true
                exitRoadLabel.isHidden = true
                exitTollboothLabel.isHidden = true
            } else {
                tollboothArrowView.isHidden = false

                if exit.road.name == entrance?.road.name {
                    exitRoadLabel.isHidden = true
                } else {
                    exitRoadLabel.isHidden = false
                    exitRoadLabel.text = exit.road.abbreviatedName
                }

                exitTollboothLabel.isHidden = false
                exitTollboothLabel.text = exit.name
            }
        } else {
            tollboothArrowView.isHidden = false
            exitRoadLabel.isHidden = true
            exitTollboothLabel.isHidden = false
            exitTollboothLabel.text = String(localized: "Unknown Tollbooth")
        }
    }

    // https://stackoverflow.com/questions/6745919/uitableviewcell-subview-disappears-when-cell-is-selected
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let color = amountView.backgroundColor
        super.setHighlighted(highlighted, animated: animated)
        amountView.backgroundColor = color
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        let color = amountView.backgroundColor
        super.setSelected(selected, animated: animated)
        amountView.backgroundColor = color
    }
}
