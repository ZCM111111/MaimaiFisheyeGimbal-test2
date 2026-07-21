import SwiftUI
import MetalKit

struct CameraPreviewView: UIViewRepresentable {
    let pixelBuffer: CVPixelBuffer?
    let metalPipeline: MetalPipeline

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
        uiView.draw()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(metalPipeline: metalPipeline)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        let metalPipeline: MetalPipeline
        var pixelBuffer: CVPixelBuffer?

        init(metalPipeline: MetalPipeline) {
            self.metalPipeline = metalPipeline
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

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(sourceTexture, index: 0)

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
