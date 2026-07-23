import MetalKit

final class MetalPipeline {
    let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?

    init?() {
        guard let dev = MTLCreateSystemDefaultDevice() else { return nil }
        device = dev
        commandQueue = dev.makeCommandQueue()!

        guard let lib = dev.makeDefaultLibrary(),
              let vs = lib.makeFunction(name: "vertexMain"),
              let fs = lib.makeFunction(name: "fragmentMain") else {
            print("⚠️ Metal library / function not found")
            return nil
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vs
        desc.fragmentFunction = fs
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipeline = try dev.makeRenderPipelineState(descriptor: desc)
        } catch {
            print("⚠️ Render pipeline error: \(error)")
            return nil
        }

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, dev, nil, &cache)
        textureCache = cache
    }

    func render(pixelBuffer: CVPixelBuffer,
                drawable: CAMetalDrawable,
                lens: LensProfile,
                stabilization: (roll: Double, pitch: Double, yaw: Double),
                settings: StabilizationSettings) {

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let tex = metalTexture(from: pixelBuffer) else { return }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = drawable.texture
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        passDesc.colorAttachments[0].storeAction = .store

        guard let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(tex, index: 0)

        // Lens uniform
        var lensUniform = MetalLens(
            focalLength: Float(lens.focalLength),
            center: SIMD2<Float>(Float(lens.centerX), Float(lens.centerY)),
            k1: Float(lens.k1),
            k2: Float(lens.k2),
            outputScale: Float(lens.outputScale)
        )
        encoder.setFragmentBytes(&lensUniform, length: MemoryLayout<MetalLens>.stride, index: 0)

        // Stabilization uniform
        let outSize = settings.resolution.size
        var stabUniform = MetalStabilizer(
            roll: Float(stabilization.roll),
            pitch: Float(stabilization.pitch),
            yaw: Float(stabilization.yaw),
            hFov: Float(settings.outputFovDeg * .pi / 180.0),
            aspect: Float(outSize.width / outSize.height),
            strength: Float(settings.strength),
            inputSize: SIMD2<Float>(Float(CVPixelBufferGetWidth(pixelBuffer)),
                                     Float(CVPixelBufferGetHeight(pixelBuffer))),
            maxRadius: 1.0
        )
        encoder.setFragmentBytes(&stabUniform, length: MemoryLayout<MetalStabilizer>.stride, index: 1)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    // MARK: - CVPixelBuffer → MTLTexture

    private func metalTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)

        var cvTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, pixelBuffer, nil,
            .bgra8Unorm, w, h, 0, &cvTex
        )
        guard let cvTex else { return nil }
        return CVMetalTextureGetTexture(cvTex)
    }
}

// MARK: - Metal-side structs (must match .metal layout exactly)

struct MetalLens {
    var focalLength: Float
    var center: SIMD2<Float>
    var k1: Float
    var k2: Float
    var outputScale: Float
}

struct MetalStabilizer {
    var roll: Float
    var pitch: Float
    var yaw: Float
    var hFov: Float
    var aspect: Float
    var strength: Float
    var inputSize: SIMD2<Float>
    var maxRadius: Float
}
