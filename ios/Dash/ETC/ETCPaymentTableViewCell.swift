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
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var roadView: UIView!
    @IBOutlet weak var roadLabel: UILabel!
    @IBOutlet weak var tollboothLabel: UILabel!
    @IBOutlet weak var arrowView: UIImageView!
    @IBOutlet weak var exitRoadView: UIView!
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
        amountLabel.text = ETCPaymentTableViewCell.numberFormatter.string(from: NSNumber(value: payment.amount))

        timeLabel.text = ETCPaymentTableViewCell.dateFormatter.string(from: payment.exitDate)

        let entrance = payment.entranceTollbooth
        let exit = payment.exitTollbooth

        if let entrance = entrance {
            roadView.isHidden = false
            roadLabel.text = entrance.road.abbreviatedName
            tollboothLabel.text = entrance.name
        } else {
            roadView.isHidden = true
            tollboothLabel.text = "不明な料金所"
        }

        if let exit = exit {
            if exit == entrance {
                arrowView.isHidden = true
                exitRoadView.isHidden = true
                exitTollboothLabel.isHidden = true
            } else {
                arrowView.isHidden = false

                if exit.road.name == entrance?.road.name {
                    exitRoadView.isHidden = true
                } else {
                    exitRoadView.isHidden = false
                    exitRoadLabel.text = exit.road.abbreviatedName
                }

                exitTollboothLabel.isHidden = false
                exitTollboothLabel.text = exit.name
            }
        } else {
            arrowView.isHidden = false
            exitRoadView.isHidden = true
            exitTollboothLabel.isHidden = false
            exitTollboothLabel.text = "不明な料金所"
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
