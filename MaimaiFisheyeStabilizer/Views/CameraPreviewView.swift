import SwiftUI
import MetalKit
import CoreVideo

struct CameraPreviewView: UIViewRepresentable {
    let device: MTLDevice
    let pixelBuffer: CVPixelBuffer?

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

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

            guard let commandBuffer = pipeline.commandQueue?.makeCommandBuffer(),
                  let renderPipelineState = pipeline.renderPipelineState else { return }

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

            encoder.setRenderPipelineState(renderPipelineState)

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
