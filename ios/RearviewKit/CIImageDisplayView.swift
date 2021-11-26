//
//  CIImageDisplayView.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2021/03/04.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MetalKit
import VideoToolbox

class CIImageDisplayView: UIView {
    enum ScalingMode {
        case aspectFit
        case aspectFill
    }

    var image: CIImage? {
        didSet {
            if let image = image {
                render(image)
            } else {
                clear()
            }
        }
    }

    var scalingMode: ScalingMode = .aspectFit

    private lazy var mtkView: MTKView = {
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.framebufferOnly = false
        return mtkView
    }()

    lazy var device: MTLDevice = MTLCreateSystemDefaultDevice()!
    lazy var commandQueue = device.makeCommandQueue()!
    lazy var ciContext = CIContext(mtlDevice: device)
    lazy var colorSpace = CGColorSpaceCreateDeviceRGB()

    private var shouldRenderImage = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        addSubview(mtkView)

        mtkView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mtkView.leftAnchor.constraint(equalTo: leftAnchor),
            mtkView.rightAnchor.constraint(equalTo: rightAnchor),
            mtkView.topAnchor.constraint(equalTo: topAnchor),
            mtkView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // https://stackoverflow.com/a/37474752/784241
    private func render(_ image: CIImage) {
        guard let drawable = mtkView.currentDrawable, let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let drawableSize = mtkView.drawableSize
        let imageToDisplay = center(scale(image, size: drawableSize), in: drawableSize)

        let destination = CIRenderDestination(
            width: drawable.texture.width,
            height: drawable.texture.height,
            pixelFormat: mtkView.colorPixelFormat,
            commandBuffer: commandBuffer
        ) {
            return drawable.texture
        }

        try! ciContext.startTask(toRender: imageToDisplay, to: destination)

        commandBuffer.present(drawable)
        commandBuffer.commit()

        mtkView.draw()
    }

    private func scale(_ image: CIImage, size: CGSize) -> CIImage {
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height

        let scale: CGFloat

        switch scalingMode {
        case .aspectFit:
            scale = min(scaleX, scaleY)
        case .aspectFill:
            scale = max(scaleX, scaleY)
        }

        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private func center(_ image: CIImage, in size: CGSize) -> CIImage {
        let originX = max(size.width - image.extent.size.width, 0) / 2
        let originY = max(size.height - image.extent.size.height, 0) / 2
        return image.transformed(by: CGAffineTransform(translationX: originX, y: originY))
    }

    private func clear() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = mtkView.currentRenderPassDescriptor,
              let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let drawable = mtkView.currentDrawable
        else { return }

        renderCommandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
