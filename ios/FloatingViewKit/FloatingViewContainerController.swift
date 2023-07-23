//
//  FloatingViewContainerController.swift
//  FloatingViewKit
//
//  Created by Yuji Nakayama on 2023/07/18.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

public protocol FloatingViewContainerControllerDelegate: NSObjectProtocol {
    func floatingViewContainerController(_ containerController: FloatingViewContainerController, didChangePosition position: FloatingPosition)
}

public enum FloatingPosition: Int {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

open class FloatingViewContainerController: UIViewController {
    static let minimumGestureVelocityMagnitudeToConsiderInertia: CGFloat = 1000

    public let floatingViewController: UIViewController

    public weak var delegate: FloatingViewContainerControllerDelegate?
    
    let floatingView: UIView

    let panGestureRecognizer = UIPanGestureRecognizer()
    
    private(set) open var position: FloatingPosition {
        didSet {
            delegate?.floatingViewContainerController(self, didChangePosition: position)
        }
    }

    public init(floatingViewController: UIViewController, initialPosition: FloatingPosition = .topLeft) {
        self.floatingViewController = floatingViewController
        self.floatingView = FloatingView(contentView: floatingViewController.view)
        self.position = initialPosition

        super.init(nibName: nil, bundle: nil)
        
        view.backgroundColor = nil
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        floatingView.isHidden = true
        
        addChild(floatingViewController)
        view.addSubview(floatingView)

        leftPositionConstraint = floatingView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor)
        rightPositionConstraint = view.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: floatingView.rightAnchor)
        topPositionConstraint = floatingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        bottomPositionConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: floatingView.bottomAnchor)
        activateConstraintsForCurrentPosition(animated: false)
        
        floatingViewController.didMove(toParent: self)

        panGestureRecognizer.addTarget(self, action: #selector(handleFloatingViewPanGesture))
        floatingView.addGestureRecognizer(panGestureRecognizer)
    }

    var leftPositionConstraint: NSLayoutConstraint!
    var rightPositionConstraint: NSLayoutConstraint!
    var topPositionConstraint: NSLayoutConstraint!
    var bottomPositionConstraint: NSLayoutConstraint!

    func activateConstraintsForCurrentPosition(animated: Bool) {
        deactivatePositionConstraints()

        let constraintsToActivate: [NSLayoutConstraint]
        
        switch position {
        case .topLeft:
            constraintsToActivate = [topPositionConstraint, leftPositionConstraint]
        case .topRight:
            constraintsToActivate = [topPositionConstraint, rightPositionConstraint]
        case .bottomLeft:
            constraintsToActivate = [bottomPositionConstraint, leftPositionConstraint]
        case .bottomRight:
            constraintsToActivate = [bottomPositionConstraint, rightPositionConstraint]
        }
        
        NSLayoutConstraint.activate(constraintsToActivate)
        
        if animated {
            UIView.animate(
                withDuration: 0.8,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.9,
                options: .curveEaseOut,
                animations: {
                    self.view.layoutIfNeeded()
                }
            )
        }
    }

    func deactivatePositionConstraints() {
        NSLayoutConstraint.deactivate([
            leftPositionConstraint,
            rightPositionConstraint,
            topPositionConstraint,
            bottomPositionConstraint
        ])
    }
    
    @objc func handleFloatingViewPanGesture() {
        switch panGestureRecognizer.state {
        case .began:
            deactivatePositionConstraints()
        case .changed:
            let delta = panGestureRecognizer.translation(in: view)
            floatingView.center = floatingView.center + delta
            panGestureRecognizer.setTranslation(.zero, in: view)
        case .ended:
            position = determinePositionFromCurrentFloatingViewCenter(andGestureVelocity: panGestureRecognizer.velocity(in: view))
            activateConstraintsForCurrentPosition(animated: true)
        case .cancelled:
            activateConstraintsForCurrentPosition(animated: true)
        default:
            break
        }
    }

    func determinePositionFromCurrentFloatingViewCenter(andGestureVelocity velocity: CGPoint) -> FloatingPosition {
        let landingPoint = calculateInertialLandingPoint(currentPoint: floatingView.center, velocity: velocity)
        return determinePosition(from: landingPoint)
    }

    func calculateInertialLandingPoint(currentPoint: CGPoint, velocity: CGPoint) -> CGPoint {
        guard velocity.magnitude >= Self.minimumGestureVelocityMagnitudeToConsiderInertia else {
            return currentPoint
        }

        let availableArea = view.bounds.inset(by: view.safeAreaInsets)

        let inertialLine = Line(start: currentPoint, end: currentPoint + velocity)
        
        for edge in availableArea.edges {
            if let intersectionPoint = interectionPointOf(inertialLine, edge) {
                return intersectionPoint
            }
        }

        return inertialLine.end
    }
    
    func determinePosition(from floatingViewCenter: CGPoint) -> FloatingPosition {
        let availableArea = view.bounds.inset(by: view.safeAreaInsets)

        if floatingViewCenter.x < availableArea.midX {
            // left
            if floatingViewCenter.y < availableArea.midY {
                return .topLeft
            } else {
                return .bottomLeft
            }
        } else {
            // right
            if floatingViewCenter.y < availableArea.midY {
                return .topRight
            } else {
                return .bottomRight
            }
        }
    }
    
    var isFloatingViewVisible: Bool {
        !floatingView.isHidden
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isFloatingViewVisible {
            floatingViewController.beginAppearanceTransition(true, animated: animated)
        }
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isFloatingViewVisible {
            floatingViewController.endAppearanceTransition()
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isFloatingViewVisible {
            floatingViewController.beginAppearanceTransition(false, animated: animated)
        }
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isFloatingViewVisible {
            floatingViewController.endAppearanceTransition()
        }
    }
    
    open func showFloatingView() {
        guard !isFloatingViewVisible else { return }
        floatingViewController.beginAppearanceTransition(true, animated: false)
        floatingView.isHidden = false
        floatingViewController.endAppearanceTransition()
    }
    
    open func hideFloatingView() {
        guard isFloatingViewVisible else { return }
        floatingViewController.beginAppearanceTransition(false, animated: false)
        floatingView.isHidden = true
        floatingViewController.endAppearanceTransition()
    }
}

fileprivate extension CGPoint {
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(
            x: left.x + right.x,
            y: left.y + right.y
        )
    }
    
    var magnitude: CGFloat {
        sqrt(pow(x, 2) + pow(y, 2))
    }
}

fileprivate extension CGRect {
    var edges: [Line] {
        [
            Line(start: CGPoint(x: minX, y: minY), end: CGPoint(x: maxX, y: minY)), // go right
            Line(start: CGPoint(x: maxX, y: minY), end: CGPoint(x: maxX, y: maxY)), // go down
            Line(start: CGPoint(x: maxX, y: maxY), end: CGPoint(x: minX, y: maxY)), // go left
            Line(start: CGPoint(x: minX, y: maxY), end: CGPoint(x: minX, y: minY)), // go up
        ]
    }
}

fileprivate struct Line {
    var start: CGPoint
    var end: CGPoint
    
    var deltaX: CGFloat {
        end.x - start.x
    }
    
    var deltaY: CGFloat {
        end.y - start.y
    }
}

// https://www.hackingwithswift.com/example-code/core-graphics/how-to-calculate-the-point-where-two-lines-intersect
fileprivate func interectionPointOf(_ lineA: Line, _ lineB: Line) -> CGPoint? {
    // create a 2D matrix from our vectors and calculate the determinant
    let determinant = lineA.deltaX * lineB.deltaY - lineB.deltaX * lineA.deltaY
    
    if abs(determinant) < 0.0001 {
        // if the determinant is effectively zero then the lines are parallel/colinear
        return nil
    }
    
    // if the coefficients both lie between 0 and 1 then we have an intersection
    let ab = ((lineA.start.y - lineB.start.y) * lineB.deltaX - (lineA.start.x - lineB.start.x) * lineB.deltaY) / determinant
    
    if 0 < ab && ab < 1 {
        let cd = ((lineA.start.y - lineB.start.y) * lineA.deltaX - (lineA.start.x - lineB.start.x) * lineA.deltaY) / determinant
        
        if 0 < cd && cd < 1 {
            // lines cross – figure out exactly where and return it
            return CGPoint(
                x: lineA.start.x + ab * lineA.deltaX,
                y: lineA.start.y + ab * lineA.deltaY
            )
        }
    }

    // lines don't cross
    return nil
}
