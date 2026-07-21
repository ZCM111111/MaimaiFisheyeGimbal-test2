import Metal
import MetalKit

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
        // 2 triangles covering the full screen
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

        // Vertex descriptor: position (float4) + texcoord (float2)
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

    // MARK: - Update uniform buffer with stabilization parameters
    func updateUniforms(roll: Float, pitch: Float, yaw: Float,
                        strength: Float, outputFov: Float,
                        focalLength: Float, principalPoint: SIMD2<Float>,
                        k1: Float, k2: Float) {
        struct Uniforms {
            var roll: Float
            var pitch: Float
            var yaw: Float
            var strength: Float
            var outputFov: Float
            var focalLength: Float
            var principalPoint: SIMD2<Float>
            var k1: Float
            var k2: Float
        }

        var uniforms = Uniforms(roll: roll, pitch: pitch, yaw: yaw, strength: strength,
                                outputFov: outputFov, focalLength: focalLength,
                                principalPoint: principalPoint, k1: k1, k2: k2)

        if uniformBuffer == nil {
            uniformBuffer = device.makeBuffer(bytes: &uniforms, length: MemoryLayout<Uniforms>.stride, options: [])
        } else {
            memcpy(uniformBuffer!.contents(), &uniforms, MemoryLayout<Uniforms>.stride)
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
