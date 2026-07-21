import Metal
import MetalKit
import CoreVideo

class MetalPipeline: ObservableObject {
    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    let renderPipelineState: MTLRenderPipelineState?
    let textureCache: CVMetalTextureCache?

    init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()

        var cache: CVMetalTextureCache?
        if let device = device {
            let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, 0, device, nil, &cache)
            self.textureCache = (result == kCVReturnSuccess) ? cache : nil
        } else {
            self.textureCache = nil
        }

        self.renderPipelineState = MetalPipeline.buildRenderPipelineState(device: device)
    }

    private static func buildRenderPipelineState(device: MTLDevice?) -> MTLRenderPipelineState? {
        guard let device = device else { return nil }

        let library = device.makeDefaultLibrary()
        guard let vertexFunction = library?.makeFunction(name: "vertexShader"),
              let fragmentFunction = library?.makeFunction(name: "fragmentShader") else {
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
            return nil
        }
    }

    func texture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard result == kCVReturnSuccess, let unwrappedCVTexture = cvTexture else {
            return nil
        }

        return CVMetalTextureGetTexture(unwrappedCVTexture)
    }
}
