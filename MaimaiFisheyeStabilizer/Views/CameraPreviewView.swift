import SwiftUI
import MetalKit
import simd

struct CameraPreviewView: UIViewRepresentable {
    let pixelBuffer: CVPixelBuffer?
    let metalPipeline: MetalPipeline
    let motion: MotionManager
    let lensProfile: LensProfile
    let stabilization: StabilizationParams

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = metalPipeline.device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        mtkView.delegate = context.coordinator
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.pixelBuffer = pixelBuffer
        context.coordinator.motion = motion
        context.coordinator.lensProfile = lensProfile
        context.coordinator.stabilization = stabilization
        uiView.draw()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(metalPipeline: metalPipeline, motion: motion)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        let metalPipeline: MetalPipeline
        var pixelBuffer: CVPixelBuffer?
        var motion: MotionManager
        var lensProfile: LensProfile = .default
        var stabilization: StabilizationParams = .default

        init(metalPipeline: MetalPipeline, motion: MotionManager) {
            self.metalPipeline = metalPipeline
            self.motion = motion
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let pixelBuffer = pixelBuffer,
                  let pipelineState = metalPipeline.pipelineState,
                  let sourceTexture = metalPipeline.makeTexture(from: pixelBuffer),
                  let vertexBuffer = metalPipeline.vertexBuffer else { return }

            guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

            guard let commandBuffer = metalPipeline.commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

            // Get texture size
            let inputWidth = Float(sourceTexture.width)
            let inputHeight = Float(sourceTexture.height)

            // Update uniforms with quaternion-based orientation
            // The shader will compute: counter_rotation = reference * inverse(current)
            // We pass the raw smoothed orientation as "orientation"
            // and the reference as "reference"
            // The shader handles the counter-rotation computation

            // For the reference, we use identity (phone's initial orientation)
            // The MotionManager already computes orientation relative to reference
            // So we can pass identity as reference and motion.orientation as orientation
            metalPipeline.updateUniforms(
                orientation: motion.orientation,
                reference: .identity, // Already relative to reference
                strength: stabilization.strength,
                outputFov: stabilization.outputFov,
                focalLength: lensProfile.focalLength,
                principalPoint: SIMD2<Float>(lensProfile.principalPointX, lensProfile.principalPointY),
                k: SIMD4<Float>(lensProfile.k1, lensProfile.k2, 0, 0),
                inputSize: SIMD2<Float>(inputWidth, inputHeight),
                outputSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(sourceTexture, index: 0)

            if let uniformBuffer = metalPipeline.uniformBuffer {
                encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            }

            // Create sampler
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
            let sampler = metalPipeline.device.makeSamplerState(descriptor: samplerDescriptor)
            encoder.setFragmentSamplerState(sampler, index: 0)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
