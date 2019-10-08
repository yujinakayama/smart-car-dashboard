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
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    @IBOutlet weak var yenLabel: UILabel!
    @IBOutlet weak var amountView: UIView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var roadLabel: UILabel!
    @IBOutlet weak var tollboothLabel: UILabel!
    @IBOutlet weak var dashLabel: UILabel!
    @IBOutlet weak var exitRoadView: UIView!
    @IBOutlet weak var exitRoadLabel: UILabel!
    @IBOutlet weak var exitTollboothLabel: UILabel!

    var payment: ETCPaymentProtocol? {
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
        amountLabel.text = payment.map { ETCPaymentTableViewCell.numberFormatter.string(from: NSNumber(value: $0.amount))! }

        dateLabel.text = payment.map { ETCPaymentTableViewCell.dateFormatter.string(from: $0.date as Date) }

        if let entrance = payment?.entranceTollbooth, let exit = payment?.exitTollbooth {
            roadLabel.text = entrance.road.abbreviatedName
            tollboothLabel.text = entrance.name

            if entrance == exit {
                dashLabel.isHidden = true
                exitRoadView.isHidden = true
                exitTollboothLabel.isHidden = true
            } else {
                dashLabel.isHidden = false

                if entrance.road.name == exit.road.name {
                    exitRoadView.isHidden = true
                } else {
                    exitRoadView.isHidden = false
                    exitRoadLabel.text = exit.road.abbreviatedName
                }

                exitTollboothLabel.isHidden = false
                exitTollboothLabel.text = exit.name
            }
        } else {
            roadLabel.text = nil
            tollboothLabel.text = nil
            exitRoadLabel.text = nil
            exitRoadLabel.text = nil
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
