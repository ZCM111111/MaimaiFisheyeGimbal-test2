import Metal
import MetalKit
import simd

// Quaternion struct matching Metal shader
struct Quat {
    var x: Float
    var y: Float
    var z: Float
    var w: Float

    static let identity = Quat(x: 0, y: 0, z: 0, w: 1)
}

// Uniform struct matching Metal shader
struct StabilizationUniforms {
    var orientation: Quat        // Current phone orientation
    var reference: Quat          // Reference (stable) orientation
    var strength: Float          // Stabilization strength (0-1)
    var outputFov: Float         // Output FOV in degrees
    var focalLength: Float       // Focal length in pixels
    var principalPoint: SIMD2<Float> // Lens center (cx, cy)
    var k: SIMD4<Float>          // Fisheye distortion coefficients
    var inputSize: SIMD2<Float>  // Input texture size
    var outputSize: SIMD2<Float> // Output texture size
}

class MetalPipeline {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState?
    var textureCache: CVMetalTextureCache?
    var vertexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = queue

        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)

        setupVertexData()
        setupPipeline()
    }

    // MARK: - Full-screen quad vertices (position + texcoord)
    private func setupVertexData() {
        let vertices: [Float] = [
            // position (x, y, z, w)   texcoord (u, v)
            -1.0,  1.0, 0.0, 1.0,    0.0, 0.0,
             1.0,  1.0, 0.0, 1.0,    1.0, 0.0,
            -1.0, -1.0, 0.0, 1.0,    0.0, 1.0,
             1.0,  1.0, 0.0, 1.0,    1.0, 0.0,
             1.0, -1.0, 0.0, 1.0,    1.0, 1.0,
            -1.0, -1.0, 0.0, 1.0,    0.0, 1.0,
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
    }

    // MARK: - Pipeline setup
    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else { return }
        guard let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentFunction") else { return }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 4
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 6
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }

    // MARK: - Update uniform buffer
    func updateUniforms(orientation: Quat, reference: Quat,
                        strength: Float, outputFov: Float,
                        focalLength: Float, principalPoint: SIMD2<Float>,
                        k: SIMD4<Float>, inputSize: SIMD2<Float>, outputSize: SIMD2<Float>) {
        var uniforms = StabilizationUniforms(
            orientation: orientation,
            reference: reference,
            strength: strength,
            outputFov: outputFov,
            focalLength: focalLength,
            principalPoint: principalPoint,
            k: k,
            inputSize: inputSize,
            outputSize: outputSize
        )

        if uniformBuffer == nil {
            uniformBuffer = device.makeBuffer(bytes: &uniforms, length: MemoryLayout<StabilizationUniforms>.stride, options: [])
        } else {
            memcpy(uniformBuffer!.contents(), &uniforms, MemoryLayout<StabilizationUniforms>.stride)
        }
    }

    // MARK: - Create Metal texture from CVPixelBuffer
    func makeTexture(from pixelBuffer: CVPixelBuffer, planeIndex: Int = 0) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil, textureCache, pixelBuffer, nil,
            .bgra8Unorm, width, height, planeIndex, &cvTexture)

        guard status == kCVReturnSuccess, let metalTexture = cvTexture else { return nil }
        return CVMetalTextureGetTexture(metalTexture)
    }
}
