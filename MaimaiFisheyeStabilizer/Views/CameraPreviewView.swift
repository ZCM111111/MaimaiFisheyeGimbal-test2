import SwiftUI
import MetalKit
import CoreVideo

struct CameraPreviewView: UIViewRepresentable {
    let device: MTLDevice
    let pixelBuffer: CVPixelBuffer?
    let roll: Double
    let pitch: Double
    let yaw: Double
    let strength: Double
    let outputFov: Double
    let focalLength: Double
    let principalPointX: Double
    let principalPointY: Double
    let k1: Double
    let k2: Double

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = device
        mtkView.backgroundColor = .black
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.delegate = context.coordinator
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.pixelBuffer = pixelBuffer
        context.coordinator.updateUniforms(
            viewSize: uiView.drawableSize,
            roll: roll,
            pitch: pitch,
            yaw: yaw,
            strength: strength,
            outputFov: outputFov,
            focalLength: focalLength,
            principalPointX: principalPointX,
            principalPointY: principalPointY,
            k1: k1,
            k2: k2
        )
        uiView.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(device: device)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        var pixelBuffer: CVPixelBuffer?
        private let pipeline: MetalPipeline

        init(device: MTLDevice) {
            self.device = device
            self.pipeline = MetalPipeline()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func updateUniforms(
            viewSize: CGSize,
            roll: Double,
            pitch: Double,
            yaw: Double,
            strength: Double,
            outputFov: Double,
            focalLength: Double,
            principalPointX: Double,
            principalPointY: Double,
            k1: Double,
            k2: Double
        ) {
            let sourceWidth: Float
            let sourceHeight: Float
            if let pixelBuffer = pixelBuffer {
                sourceWidth = Float(CVPixelBufferGetWidth(pixelBuffer))
                sourceHeight = Float(CVPixelBufferGetHeight(pixelBuffer))
            } else {
                sourceWidth = 1920.0
                sourceHeight = 1080.0
            }

            pipeline.updateUniforms(
                roll: Float(roll),
                pitch: Float(pitch),
                yaw: Float(yaw),
                strength: Float(strength),
                outputFov: Float(outputFov),
                focalLength: Float(focalLength),
                principalPoint: SIMD2<Float>(Float(principalPointX), Float(principalPointY)),
                k1: Float(k1),
                k2: Float(k2),
                viewportSize: SIMD2<Float>(Float(viewSize.width), Float(viewSize.height)),
                sourceTextureSize: SIMD2<Float>(sourceWidth, sourceHeight)
            )
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

            guard let commandBuffer = pipeline.commandQueue?.makeCommandBuffer(),
                  let renderPipelineState = pipeline.renderPipelineState else { return }

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

            encoder.setRenderPipelineState(renderPipelineState)

            // Bind uniform buffer at fragment stage, buffer index 0
            if let uniformBuffer = pipeline.getUniformBuffer() {
                encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            }

            if let pixelBuffer = pixelBuffer, let texture = pipeline.texture(from: pixelBuffer) {
                encoder.setFragmentTexture(texture, index: 0)
            }

            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
