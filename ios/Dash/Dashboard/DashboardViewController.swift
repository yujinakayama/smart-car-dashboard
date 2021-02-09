//
//  DashboardViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

// Container view controller
class DashboardViewController: UIViewController {
    enum LayoutMode {
        case fullMusicView
        case split
    }

    @IBOutlet weak var widgetView: UIView!
    @IBOutlet weak var musicContainerView: UIView!
    @IBOutlet weak var musicEdgeGlossView: UIView!

    lazy var widgetViewController: UIViewController = children.first { $0 is WidgetPageViewController }!
    lazy var musicViewController: MusicViewController = children.first { $0 is MusicViewController } as! MusicViewController

    @IBOutlet weak var musicContainerViewTopConstraintForSplitLayout: NSLayoutConstraint!
    @IBOutlet weak var musicContainerViewTopConstraintForFullMusicLayout: NSLayoutConstraint!
    @IBOutlet weak var musicContainerViewTopConstraintForDraggingState: NSLayoutConstraint!

    var currentLayoutMode: LayoutMode = .fullMusicView

    var layoutSwitchGesture: LayoutSwitchGesture {
        return LayoutSwitchGesture(
            gestureRecognizer: musicViewController.panGestureRecognizer,
            currentLayoutMode: currentLayoutMode,
            currentSplitPosition: musicContainerView.frame.origin.y,
            fullSplitPosition: widgetView.frame.maxY
        )
    }

    var hasBegunMusicViewAppearanceTransition = false

    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLayoutConstraint.activate([
            musicEdgeGlossView.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])

        musicViewController.panGestureRecognizer.addTarget(self, action: #selector(gestureRecognizerDidRecognizePanGesture))

        updateMusicContainerViewShadow()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if currentLayoutMode == .split {
            widgetViewController.beginAppearanceTransition(true, animated: animated)
        }

        musicViewController.beginAppearanceTransition(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if currentLayoutMode == .split {
            widgetViewController.endAppearanceTransition()
        }

        musicViewController.endAppearanceTransition()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if currentLayoutMode == .split {
            widgetViewController.beginAppearanceTransition(false, animated: animated)
        }

        musicViewController.beginAppearanceTransition(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if currentLayoutMode == .split {
            widgetViewController.endAppearanceTransition()
        }

        musicViewController.endAppearanceTransition()
    }

    @objc func gestureRecognizerDidRecognizePanGesture(gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            // We don't invoke widgetViewController.beginAppearanceTransition() here
            // to avoid inefficient invocation of viewWillAppear() in MusicViewController
            // with pan gestures that actually don't switch layout
            hasBegunMusicViewAppearanceTransition = false
        case .changed:
            if !hasBegunMusicViewAppearanceTransition, layoutSwitchGesture.isConsideredToBeTryingToSwitchLayout {
                widgetViewController.beginAppearanceTransition(currentLayoutMode == .fullMusicView, animated: true)
                hasBegunMusicViewAppearanceTransition = true
            }
            updateLayoutConstraintForDraggingState(gestureRecognizer: gestureRecognizer)
        case .ended:
            switchLayoutWithAnimation(gestureRecognizer: gestureRecognizer)
        default:
            break
        }
    }

    private func updateLayoutConstraintForDraggingState(gestureRecognizer: UIPanGestureRecognizer) {
        musicContainerViewTopConstraintForSplitLayout.isActive = false
        musicContainerViewTopConstraintForFullMusicLayout.isActive = false

        musicContainerViewTopConstraintForDraggingState.constant = layoutSwitchGesture.splitPosition
        musicContainerViewTopConstraintForDraggingState.isActive = true

        view.layoutIfNeeded()
    }

    private func switchLayoutWithAnimation(gestureRecognizer: UIPanGestureRecognizer) {
        view.layoutIfNeeded()

        let finalLayoutMode = layoutSwitchGesture.finalLayoutMode

        musicContainerViewTopConstraintForDraggingState.isActive = false
        musicContainerViewTopConstraintForSplitLayout.isActive = finalLayoutMode == .split
        musicContainerViewTopConstraintForFullMusicLayout.isActive = finalLayoutMode == .fullMusicView

        if (!hasBegunMusicViewAppearanceTransition && finalLayoutMode != currentLayoutMode) // Transitioning but hasn't notified
        || (hasBegunMusicViewAppearanceTransition && finalLayoutMode == currentLayoutMode)  // Canceling transition so we need to notify of opposite one
        {
            widgetViewController.beginAppearanceTransition(finalLayoutMode == .split, animated: true)
            hasBegunMusicViewAppearanceTransition = true
        }

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1) {
            self.view.layoutIfNeeded()
        } completion: { (finished) in
            self.currentLayoutMode = finalLayoutMode

            if self.hasBegunMusicViewAppearanceTransition {
                self.widgetViewController.endAppearanceTransition()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateMusicContainerViewShadow()
        }
    }

    private func updateMusicContainerViewShadow() {
        musicContainerView.layer.shadowColor = UIColor.black.cgColor
        musicContainerView.layer.shadowOffset = CGSize.zero
        musicContainerView.layer.shadowRadius = 20

        switch traitCollection.userInterfaceStyle {
        case .dark:
            musicContainerView.layer.shadowOpacity = 0.5
            musicEdgeGlossView.backgroundColor = UIColor(white: 1, alpha: 0.15)
        default:
            musicContainerView.layer.shadowOpacity = 0.15
            musicEdgeGlossView.backgroundColor = .white
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        musicEdgeGlossView.isHidden = musicContainerView.frame.origin.y == 0
    }
}

extension DashboardViewController {
    class LayoutSwitchGesture {
        let absoluteGestureVelocityToSwitchLayout: CGFloat = 1000
        let minimumDeltaToBeConsideredAsTryingToSwitchLayout: CGFloat = 20

        let gestureRecognizer: UIPanGestureRecognizer
        let currentLayoutMode: LayoutMode
        let currentSplitPosition: CGFloat
        let fullSplitPosition: CGFloat

        init(gestureRecognizer: UIPanGestureRecognizer, currentLayoutMode: LayoutMode, currentSplitPosition: CGFloat, fullSplitPosition: CGFloat) {
            self.gestureRecognizer = gestureRecognizer
            self.currentLayoutMode = currentLayoutMode
            self.currentSplitPosition = currentSplitPosition
            self.fullSplitPosition = fullSplitPosition
        }

        var isConsideredToBeTryingToSwitchLayout: Bool {
            let positiveDelta = delta * (currentLayoutMode == .fullMusicView ? 1 : -1)
            return positiveDelta >= minimumDeltaToBeConsideredAsTryingToSwitchLayout
        }

        var splitPosition: CGFloat {
            let initialSplitPosition = (currentLayoutMode == .split) ? fullSplitPosition : 0
            let unlimitedSplitPosition = initialSplitPosition + delta
            return (unlimitedSplitPosition...unlimitedSplitPosition).clamped(to: 0...fullSplitPosition).lowerBound
        }

        var finalLayoutMode: LayoutMode {
            let velocity = gestureRecognizer.velocity(in: nil).y

            if abs(velocity) >= absoluteGestureVelocityToSwitchLayout {
                if velocity > 0 {
                    return .split
                } else {
                    return .fullMusicView
                }
            } else {
                if currentSplitPosition >= (fullSplitPosition / 2) {
                    return .split
                } else {
                    return .fullMusicView
                }
            }
        }

        var delta: CGFloat {
            return gestureRecognizer.translation(in: nil).y
        }
    }
}
