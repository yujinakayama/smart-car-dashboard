//
//  ETCCardTableViewCell.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCCardTableViewCell: UITableViewCell {
    static let signatureImage = UIImage(systemName: "signature")!
    static let visaImage = UIImage(named: "Visa")!
    static let mastercardImage = UIImage(named: "Mastercard")!

    @IBOutlet weak var cardView: ETCCardView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var checkmarkImageView: UIImageView!

    var card: ETCCard! {
        didSet {
            updateCardView()
            updateNameLabel()
        }
    }

    var isCurrentCard = false {
        didSet {
            checkmarkImageView.isHidden = !isCurrentCard
        }
    }

    func updateCardView() {
        switch card.brand {
        case .unknown:
            cardView.image = ETCCardTableViewCell.signatureImage
            cardView.tintColor = .white
            cardView.backgroundColor = .darkGray
        case .visa:
            cardView.image = ETCCardTableViewCell.visaImage
            cardView.tintColor = .white
            cardView.backgroundColor = UIColor(named: "Visa Background Color")
        case .mastercard:
            cardView.image = ETCCardTableViewCell.mastercardImage
            cardView.tintColor = nil
            cardView.backgroundColor = .black
        }
    }

    func updateNameLabel() {
        nameLabel.text = card.displayedName

        if card.name.isEmpty {
            nameLabel.textColor = UIColor.secondaryLabel
        } else {
            nameLabel.textColor = UIColor.label
        }
    }
}
