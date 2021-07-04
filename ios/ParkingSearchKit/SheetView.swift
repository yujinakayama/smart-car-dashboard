//
//  SheetView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/07/04.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

@IBDesignable public class SheetView: UIView {
    public var placement: Placement = .bottomAttached {
        didSet {
            applyCornerMasks()
            uninstallPlacementConstraints()
            installPlacementConstraints()
        }
    }

    public var placementMargin: CGFloat = 20

    private let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))

    private var verticalConstraintForHiddenState: NSLayoutConstraint?
    private var verticalConstraintForShownState: NSLayoutConstraint?
    private var otherConstraints: [NSLayoutConstraint] = []

    private var placementConstraints: [NSLayoutConstraint] {
        return [verticalConstraintForHiddenState, verticalConstraintForShownState].compactMap { $0 } + otherConstraints
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    private func commonInit() {
        layoutMargins = .init(top: 16, left: 16, bottom: 16, right: 16)
        translatesAutoresizingMaskIntoConstraints = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 8
        updateShadow()

        visualEffectView.layer.cornerCurve = .continuous
        visualEffectView.layer.cornerRadius = 12
        visualEffectView.layer.masksToBounds = true
        applyCornerMasks()

        insertSubview(visualEffectView, at: 0)

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])
    }

    func applyCornerMasks() {
        if placement == .bottomAttached {
            visualEffectView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else {
            visualEffectView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
    }

    public override func didMoveToSuperview() {
        uninstallPlacementConstraints()
        installPlacementConstraints()
    }

    private func uninstallPlacementConstraints() {
        NSLayoutConstraint.deactivate(placementConstraints)
        verticalConstraintForHiddenState = nil
        verticalConstraintForShownState = nil
        otherConstraints = []
    }

    private func installPlacementConstraints() {
        guard let superview = superview else { return }

        switch placement {
        case .bottomAttached:
            verticalConstraintForHiddenState = topAnchor.constraint(equalTo: superview.bottomAnchor)
            verticalConstraintForShownState = superview.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: bottomAnchor)
            otherConstraints = [
                leftAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leftAnchor),
                superview.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: rightAnchor),
            ]
        default:
            if placement.isAnchoredToLeft {
                otherConstraints.append(leftAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leftAnchor, constant: placementMargin))
            }

            if placement.isAnchoredToRight {
                otherConstraints.append(superview.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: rightAnchor, constant: placementMargin))
            }

            if placement.isAnchoredToTop {
                verticalConstraintForHiddenState = superview.topAnchor.constraint(equalTo: bottomAnchor)
                verticalConstraintForShownState = topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: placementMargin)
            }

            if placement.isAnchoredToBottom {
                verticalConstraintForHiddenState = topAnchor.constraint(equalTo: superview.bottomAnchor)
                verticalConstraintForShownState = superview.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: bottomAnchor, constant: placementMargin)
            }

//            otherConstraints.append(widthAnchor.constraint(equalToConstant: 400))
        }

        if isHidden {
            verticalConstraintForHiddenState?.isActive = true
        } else {
            verticalConstraintForShownState?.isActive = true
        }

        NSLayoutConstraint.activate(otherConstraints)
    }


    public func show() {
        guard isHidden else { return }

        verticalConstraintForHiddenState?.isActive = false
        verticalConstraintForShownState?.isActive = true

        isHidden = false

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.superview?.layoutIfNeeded()
        }
    }

    public func hide() {
        guard !isHidden else { return }

        verticalConstraintForShownState?.isActive = false
        verticalConstraintForHiddenState?.isActive = true

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.superview?.layoutIfNeeded()
        } completion: { (finished) in
            self.isHidden = true
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
            layer.shadowOpacity = 0.25
        } else {
            layer.shadowOpacity = 0.15
        }
    }
}

extension SheetView {
    public enum Placement {
        case leftTop
        case rightTop
        case leftBottom
        case rightBottom
        case bottomAttached

        var isAnchoredToLeft: Bool {
            return self == .leftTop || self == .leftBottom
        }

        var isAnchoredToRight: Bool {
            return self == .rightTop || self == .rightBottom
        }

        var isAnchoredToTop: Bool {
            return self == .leftTop || self == .rightTop
        }

        var isAnchoredToBottom: Bool {
            return self == .leftBottom || self == .rightBottom
        }
    }
}
