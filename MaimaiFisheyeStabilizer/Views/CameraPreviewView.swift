import SwiftUI
import MetalKit

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

            // Update uniforms with current motion data
            metalPipeline.updateUniforms(
                roll: Float(motion.roll),
                pitch: Float(motion.pitch),
                yaw: Float(motion.yaw),
                strength: stabilization.strength,
                outputFov: stabilization.outputFov,
                focalLength: lensProfile.focalLength,
                principalPoint: SIMD2<Float>(lensProfile.principalPointX, lensProfile.principalPointY),
                k1: lensProfile.k1,
                k2: lensProfile.k2
            )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(sourceTexture, index: 0)

            if let uniformBuffer = metalPipeline.uniformBuffer {
                encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            }

            // Create sampler descriptor
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
