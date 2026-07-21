import Metal
import MetalKit
import CoreVideo

/// Uniforms structure matching the Metal shader's StabilizerUniforms
struct StabilizerUniforms {
    var roll: Float
    var pitch: Float
    var yaw: Float
    var strength: Float
    var outputFov: Float
    var viewportSize: SIMD2<Float>
    var sourceTextureSize: SIMD2<Float>
}

class MetalPipeline: ObservableObject {
    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    let renderPipelineState: MTLRenderPipelineState?
    let textureCache: CVMetalTextureCache?

    // Uniform buffer
    private var uniformBuffer: MTLBuffer?
    private var currentUniforms: StabilizerUniforms

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

        // Initialize default uniforms
        self.currentUniforms = StabilizerUniforms(
            roll: 0.0,
            pitch: 0.0,
            yaw: 0.0,
            strength: 1.0,
            outputFov: 100.0,
            viewportSize: SIMD2<Float>(1920.0, 1080.0),
            sourceTextureSize: SIMD2<Float>(1920.0, 1080.0)
        )

        self.renderPipelineState = MetalPipeline.buildRenderPipelineState(device: device)

        // Create uniform buffer
        if let device = device {
            self.uniformBuffer = device.makeBuffer(
                length: MemoryLayout<StabilizerUniforms>.stride,
                options: .storageModeShared
            )
            // Initialize with default values
            updateUniformBuffer()
        }
    }

    /// Update uniforms with motion data
    func updateUniforms(
        roll: Float,
        pitch: Float,
        yaw: Float,
        strength: Float,
        outputFov: Float,
        viewportSize: SIMD2<Float>,
        sourceTextureSize: SIMD2<Float>
    ) {
        currentUniforms.roll = roll
        currentUniforms.pitch = pitch
        currentUniforms.yaw = yaw
        currentUniforms.strength = strength
        currentUniforms.outputFov = outputFov
        currentUniforms.viewportSize = viewportSize
        currentUniforms.sourceTextureSize = sourceTextureSize

        updateUniformBuffer()
    }

    /// Get the current uniforms (for read access)
    var uniforms: StabilizerUniforms {
        return currentUniforms
    }

    private func updateUniformBuffer() {
        guard let uniformBuffer = uniformBuffer else { return }
        let bufferPointer = uniformBuffer.contents()
        let uniformsPointer = bufferPointer.bindMemory(to: StabilizerUniforms.self, capacity: 1)
        uniformsPointer[0] = currentUniforms
    }

    /// Get the Metal buffer for binding to the shader
    func getUniformBuffer() -> MTLBuffer? {
        return uniformBuffer
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
