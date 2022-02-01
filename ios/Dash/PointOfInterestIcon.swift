//
//  PointOfInterestIcon.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/12/13.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import UIKit

struct PointOfInterestIcon {
    var image: UIImage
    var color: UIColor

    init(image: UIImage, color: UIColor) {
        self.image = image
        self.color = color
    }

    init(location: Location) {
        for category in location.categories {
            if let icon = specificIcon(for: category) {
                self = icon
                return
            }
        }

        self = genericIcon(for: location)
    }
}

fileprivate func specificIcon(for category: Location.Category) -> PointOfInterestIcon? {
    let image: UIImage?
    let color: UIColor?

    switch category {
    case .airport:
        image = UIImage(systemName: "airplane")!
        color = UIColor(rgb: 0x6599F8)
    case .buddhistTemple:
        image = UIImage(named: "manji")!
        color = UIColor(rgb: 0xA8825B)
    case .cafe:
        image = UIImage(systemName: "cup.and.saucer.fill")!
        color = UIColor(rgb: 0xEA9A52)
    case .carRepair:
        image = UIImage(systemName: "wrench.fill")!
        color = UIColor(rgb: 0x7381AF)
    case .cityHall, .localGovernmentOffice, .museum:
        image = UIImage(systemName: "building.columns.fill")!
        color = UIColor(rgb: 0x7381AF)
    case .doctor:
        image = UIImage(systemName: "stethoscope")!
        color = UIColor(rgb: 0xE9675F)
    case .gasStation:
        image = UIImage(systemName: "fuelpump.fill")!
        color = UIColor(rgb: 0x4B9EF8)
    case .hospital:
        image = UIImage(systemName: "cross.fill")!
        color = UIColor(rgb: 0xE9675F)
    case .hotel, .lodging:
        image = UIImage(systemName: "bed.double.fill")!
        color = UIColor(rgb: 0x9688F7)
    case .mealTakeaway, .mealDelivery:
        image = UIImage(systemName: "takeoutbag.and.cup.and.straw.fill")!
        color = UIColor(rgb: 0xEA9A52)
    case .nightClub, .nightlife:
        image = UIImage(systemName: "music.quarternote.3")!
        color = UIColor(rgb: 0xD673D1)
    case .park, .nationalPark:
        image = UIImage(systemName: "leaf.fill")!
        color = UIColor(rgb: 0x54B741)
    case .parking:
        image = UIImage(systemName: "parkingsign")!
        color = UIColor(rgb: 0x4C9EF8)
    case .pharmacy, .drugstore:
        image = UIImage(systemName: "pills")!
        color = UIColor(rgb: 0xEC6860)
    case .publicTransport, .trainStation, .subwayStation, .lightRailStation, .transitStation:
        image = UIImage(systemName: "tram.fill")!
        color = UIColor(rgb: 0x4C9EF8)
    case .rendezvous:
        image = UIImage(systemName: "hand.raised.fill")!
        color = UIColor(rgb: 0xEB5674)
    case .restArea:
        image = UIImage(systemName: "parkingsign")!
        color = UIColor(rgb: 0x5AC177)
    case .restaurant:
        image = UIImage(systemName: "fork.knife")!
        color = UIColor(rgb: 0xEA9A52)
    case .school, .primarySchool, .secondarySchool:
        image = UIImage(named: "bun")!
        color = UIColor(rgb: 0x9F7650)
    case .shintoShrine:
        image = UIImage(named: "torii")!
        color = UIColor(rgb: 0xA8825B)
    case .spa:
        image = UIImage(named: "hotspring")!
        color = UIColor(rgb: 0xEC6860)
    case .store, .bookStore, .clothingStore, .departmentStore, .electronicsStore, .furnitureStore, .hardwareStore, .homeGoodsStore, .jewelryStore, .shoppingMall:
        image = UIImage(systemName: "bag.fill")!
        color = UIColor(rgb: 0xF3B63F)
    case .supermarket, .foodMarket, .groceryOrSupermarket:
        image = UIImage(systemName: "cart")!
        color = UIColor(rgb: 0xF3B63F)
    case .theater, .movieTheater:
        image = UIImage(systemName: "theatermasks.fill")!
        color = UIColor(rgb: 0xD673D1)
    case .university:
        image = UIImage(systemName: "graduationcap.fill")!
        color = UIColor(rgb: 0x9F7650)
    default:
        image = nil
        color = nil
    }

    if let image = image, let color = color {
        return PointOfInterestIcon(image: image, color: color)
    } else {
        return nil
    }
}

fileprivate func genericIcon(for location: Location) -> PointOfInterestIcon {
    if location.categories.contains(.food) {
        return PointOfInterestIcon(
            image: UIImage(systemName: "takeoutbag.and.cup.and.straw.fill")!,
            color: UIColor(rgb: 0xEA9A52)
        )
    }

    if location.categories.contains(.naturalFeature) {
        return PointOfInterestIcon(
            image: UIImage(systemName: "leaf.fill")!,
            color: UIColor(rgb: 0x54B741)
        )
    }

    if location.categories.contains(.touristAttraction) {
        return PointOfInterestIcon(
            image: UIImage(systemName: "star.fill")!,
            color: UIColor(rgb: 0x969696)
        )
    }

    return PointOfInterestIcon(
        image: UIImage(systemName: "mappin")!,
        color: UIColor(rgb: 0xEB5956)
    )
}

fileprivate extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
       assert(red >= 0 && red <= 255, "Invalid red component")
       assert(green >= 0 && green <= 255, "Invalid green component")
       assert(blue >= 0 && blue <= 255, "Invalid blue component")

       self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
   }

   convenience init(rgb: Int) {
       self.init(
           red: (rgb >> 16) & 0xFF,
           green: (rgb >> 8) & 0xFF,
           blue: rgb & 0xFF
       )
   }
}
