import Metal
import MetalKit
import simd
import SwiftUI
import Foundation

/// High-performance Metal-based rendering pipeline for Pointly
/// 
/// **Design Decision**: Metal over Core Graphics for:
/// - 120Hz rendering capability on ProMotion displays
/// - Sub-5ms drawing latency for professional use
/// - GPU-accelerated effects (blur, glow, pressure sensitivity)
/// - Scalable to complex features (layers, effects, collaboration cursors)
///
/// **Architecture**: Command buffer based rendering with reusable pipelines
class MetalRenderer: ObservableObject {
    
    // MARK: - Metal Resources
    
    let device: MTLDevice                       // internal — read by MetalView
    private let commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    
    // MARK: - Rendering State
    
    @Published var isReady: Bool = false
    @Published var renderingStats: RenderingStats = RenderingStats()
    
    /// Current frame rate target (60Hz, 120Hz, etc.)
    @Published var targetFrameRate: Int = 60
    
    /// Whether to prefer high performance GPU
    @Published var preferHighPerformanceGPU: Bool = true
    
    // MARK: - Performance Monitoring
    
    private var frameStartTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastStatsUpdate: CFTimeInterval = 0
    
    // MARK: - Initialization
    
    init() throws {
        // Get Metal device (prefer high-performance GPU for drawing apps)
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalRendererError.deviceNotAvailable
        }
        
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalRendererError.commandQueueCreationFailed
        }
        
        self.commandQueue = commandQueue
        commandQueue.label = "Pointly Rendering Queue"
        
        // Initialize rendering pipeline
        try setupRenderingPipeline()
        
        print("🎨 Metal Renderer initialized with device: \(device.name)")
        print("📊 Supports 120Hz: \(supportsHighRefreshRate)")
        
        isReady = true
    }
    
    // MARK: - Public Rendering Methods
    
    /// Render drawing elements to the specified drawable
    /// - Parameters:
    ///   - elements: Drawing elements to render
    ///   - drawable: Metal drawable to render to
    ///   - viewportSize: Size of the rendering viewport
    func render(elements: [DrawingElement], to drawable: MTLDrawable, viewportSize: CGSize) {
        guard isReady else { return }
        
        frameStartTime = CACurrentMediaTime()
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        commandBuffer.label = "Pointly Render Commands"
        
        // Setup render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = (drawable as? CAMetalDrawable)?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderEncoder.label = "Pointly Render Encoder"
        
        // Set viewport
        let viewport = MTLViewport(
            originX: 0, originY: 0,
            width: Double(viewportSize.width),
            height: Double(viewportSize.height),
            znear: 0.0, zfar: 1.0
        )
        renderEncoder.setViewport(viewport)
        
        // Render each drawing element
        for element in elements {
            renderElement(element, with: renderEncoder, viewportSize: viewportSize)
        }
        
        renderEncoder.endEncoding()
        
        // Present the drawable
        commandBuffer.present(drawable)
        
        // Add completion handler for performance monitoring
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.updateRenderingStats()
        }
        
        commandBuffer.commit()
    }
    
    /// Create optimized vertex data for smooth drawing
    /// - Parameter points: Input points from drawing gesture
    /// - Returns: Optimized vertex array for Metal rendering
    func createSmoothPath(from points: [CGPoint]) -> [MetalVertex] {
        guard points.count > 1 else {
            // Single point - create small circle
            if let point = points.first {
                return createCircleVertices(center: point, radius: 2.0)
            }
            return []
        }
        
        var vertices: [MetalVertex] = []
        
        // Use Catmull-Rom spline for smooth curves
        let smoothPoints = applyCatmullRomSmoothing(to: points)
        
        // Convert to triangle strip for efficient rendering
        for i in 0..<(smoothPoints.count - 1) {
            let p1 = smoothPoints[i]
            let p2 = smoothPoints[i + 1]
            
            // Calculate perpendicular for stroke width
            let direction = simd_float2(Float(p2.x - p1.x), Float(p2.y - p1.y))
            let length = simd_length(direction)
            
            if length > 0 {
                let normalized = direction / length
                let perpendicular = simd_float2(-normalized.y, normalized.x)
                
                // Create quad vertices for stroke segment
                let thickness: Float = 2.0  // Will be configurable
                vertices.append(contentsOf: createStrokeQuad(
                    p1: p1, p2: p2,
                    perpendicular: perpendicular,
                    thickness: thickness
                ))
            }
        }
        
        return vertices
    }
    
    // MARK: - Tool-Specific Rendering
    
    /// Render marker tool with texture and blending
    /// - Parameters:
    ///   - element: Drawing element with marker tool
    ///   - encoder: Metal render encoder
    ///   - viewportSize: Rendering viewport size
    func renderMarker(_ element: DrawingElement, with encoder: MTLRenderCommandEncoder, viewportSize: CGSize) {
        // Marker uses alpha blending and texture for realistic feel
        let vertices = createSmoothPath(from: element.points)
        
        // Apply marker-specific rendering properties
        var markerUniforms = MarkerUniforms(
            opacity: Float(element.opacity),
            color: element.color.metalColor,
            texture: .marker,
            blendMode: .multiply
        )
        
        renderVertices(vertices, uniforms: &markerUniforms, encoder: encoder)
    }
    
    /// Render laser pointer with glow and fade effect
    /// - Parameters:
    ///   - element: Drawing element with laser pointer tool
    ///   - encoder: Metal render encoder
    ///   - viewportSize: Rendering viewport size
    func renderLaserPointer(_ element: DrawingElement, with encoder: MTLRenderCommandEncoder, viewportSize: CGSize) {
        // Laser pointer has animated glow and temporal fade
        let vertices = createSmoothPath(from: element.points)
        
        // Calculate fade based on element age
        let age = Date().timeIntervalSince(element.timestamp)
        let fadeOpacity = max(0, Float(element.opacity) * (1.0 - Float(age) / 3.0))  // 3-second fade
        
        var laserUniforms = LaserUniforms(
            opacity: fadeOpacity,
            color: element.color.metalColor,
            glowRadius: 8.0,
            animationTime: Float(age)
        )
        
        renderVertices(vertices, uniforms: &laserUniforms, encoder: encoder)
    }
    
    /// Render blur/pixel brush with custom fragment shader
    /// - Parameters:
    ///   - element: Drawing element with blur brush tool
    ///   - encoder: Metal render encoder
    ///   - viewportSize: Rendering viewport size
    func renderBlurBrush(_ element: DrawingElement, with encoder: MTLRenderCommandEncoder, viewportSize: CGSize) {
        // Blur brush applies screen-space blur effect
        let vertices = createSmoothPath(from: element.points)
        
        var blurUniforms = BlurUniforms(
            opacity: Float(element.opacity),
            blurRadius: Float(element.thickness * 0.5),
            sampleCount: 8  // Quality vs performance trade-off
        )
        
        renderVertices(vertices, uniforms: &blurUniforms, encoder: encoder)
    }
    
    // MARK: - Performance & Capabilities
    
    /// Whether the device supports high refresh rate rendering (120Hz)
    var supportsHighRefreshRate: Bool {
        // Check for ProMotion support (simplified check)
        return device.supportsFamily(.mac2) || device.supportsFamily(.macCatalyst2)
    }
    
    /// Current rendering performance metrics
    struct RenderingStats {
        var averageFrameTime: Double = 0
        var currentFPS: Double = 0
        var droppedFrames: Int = 0
        var gpuUtilization: Double = 0
    }
    
    // MARK: - Private Implementation
    
    private func setupRenderingPipeline() throws {
        // Load Metal shaders
        guard let library = device.makeDefaultLibrary() else {
            throw MetalRendererError.shaderLibraryNotFound
        }
        
        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            throw MetalRendererError.shaderFunctionNotFound
        }
        
        // Create render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Pointly Drawing Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable alpha blending for transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func renderElement(_ element: DrawingElement, with encoder: MTLRenderCommandEncoder, viewportSize: CGSize) {
        switch element.tool {
        case .pen, .highlighter:
            renderStandardTool(element, with: encoder, viewportSize: viewportSize)
        case .marker:
            renderMarker(element, with: encoder, viewportSize: viewportSize)
        case .laserPointer:
            renderLaserPointer(element, with: encoder, viewportSize: viewportSize)
        case .blurBrush:
            renderBlurBrush(element, with: encoder, viewportSize: viewportSize)
        default:
            renderStandardTool(element, with: encoder, viewportSize: viewportSize)
        }
    }
    
    private func renderStandardTool(_ element: DrawingElement, with encoder: MTLRenderCommandEncoder, viewportSize: CGSize) {
        let vertices = createSmoothPath(from: element.points)
        
        var uniforms = StandardUniforms(
            opacity: Float(element.opacity),
            color: element.color.metalColor,
            thickness: Float(element.thickness)
        )
        
        renderVertices(vertices, uniforms: &uniforms, encoder: encoder)
    }
    
    private func renderVertices<T>(_ vertices: [MetalVertex], uniforms: inout T, encoder: MTLRenderCommandEncoder) {
        guard !vertices.isEmpty,
              let pipelineState = renderPipelineState else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        
        // Create vertex buffer
        let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<MetalVertex>.stride,
            options: []
        )
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<T>.size, index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }
    
    private func updateRenderingStats() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let frameTime = currentTime - frameStartTime
        
        // Update stats every second
        if currentTime - lastStatsUpdate >= 1.0 {
            renderingStats.currentFPS = Double(frameCount)
            renderingStats.averageFrameTime = frameTime
            
            frameCount = 0
            lastStatsUpdate = currentTime
            
            // Log performance metrics
            if renderingStats.averageFrameTime > 0.016 {  // > 16ms (below 60fps)
                print("⚠️ Rendering performance: \(String(format: "%.1f", renderingStats.currentFPS)) FPS")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func applyCatmullRomSmoothing(to points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        var smoothed: [CGPoint] = []
        
        // Add first point
        smoothed.append(points[0])
        
        // Apply Catmull-Rom interpolation
        for i in 1..<(points.count - 1) {
            let p0 = i > 1 ? points[i - 2] : points[i - 1]
            let p1 = points[i - 1]
            let p2 = points[i]
            let p3 = i < points.count - 1 ? points[i + 1] : points[i]
            
            // Generate interpolated points
            for t in stride(from: 0.0, through: 1.0, by: 0.25) {
                let point = catmullRomInterpolate(p0: p0, p1: p1, p2: p2, p3: p3, t: CGFloat(t))
                smoothed.append(point)
            }
        }
        
        // Add last point
        smoothed.append(points.last!)
        
        return smoothed
    }
    
    private func catmullRomInterpolate(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        
        let x = 0.5 * ((2 * p1.x) +
                       (-p0.x + p2.x) * t +
                       (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                       (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
        
        let y = 0.5 * ((2 * p1.y) +
                       (-p0.y + p2.y) * t +
                       (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                       (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
        
        return CGPoint(x: x, y: y)
    }
    
    private func createStrokeQuad(p1: CGPoint, p2: CGPoint, perpendicular: simd_float2, thickness: Float) -> [MetalVertex] {
        let p1f = simd_float2(Float(p1.x), Float(p1.y))
        let p2f = simd_float2(Float(p2.x), Float(p2.y))
        let offset = perpendicular * (thickness * 0.5)
        
        return [
            MetalVertex(position: p1f - offset, texCoord: simd_float2(0, 0)),
            MetalVertex(position: p1f + offset, texCoord: simd_float2(1, 0)),
            MetalVertex(position: p2f - offset, texCoord: simd_float2(0, 1)),
            MetalVertex(position: p2f + offset, texCoord: simd_float2(1, 1))
        ]
    }
    
    private func createCircleVertices(center: CGPoint, radius: CGFloat) -> [MetalVertex] {
        var vertices: [MetalVertex] = []
        let segments = 16
        
        let centerF = simd_float2(Float(center.x), Float(center.y))
        
        for i in 0...segments {
            let angle = Float(i) * 2.0 * Float.pi / Float(segments)
            let x = centerF.x + Float(radius) * cos(angle)
            let y = centerF.y + Float(radius) * sin(angle)
            
            vertices.append(MetalVertex(
                position: simd_float2(x, y),
                texCoord: simd_float2(cos(angle) * 0.5 + 0.5, sin(angle) * 0.5 + 0.5)
            ))
        }
        
        return vertices
    }
}

// MARK: - Metal Data Structures

/// Vertex structure for Metal rendering
struct MetalVertex {
    let position: simd_float2
    let texCoord: simd_float2
}

/// Standard tool rendering uniforms
struct StandardUniforms {
    let opacity: Float
    let color: simd_float4
    let thickness: Float
}

/// Marker tool specific uniforms
struct MarkerUniforms {
    let opacity: Float
    let color: simd_float4
    let texture: MetalTextureType
    let blendMode: MetalBlendMode
}

/// Laser pointer specific uniforms
struct LaserUniforms {
    let opacity: Float
    let color: simd_float4
    let glowRadius: Float
    let animationTime: Float
}

/// Blur brush specific uniforms
struct BlurUniforms {
    let opacity: Float
    let blurRadius: Float
    let sampleCount: Int32
}

// MARK: - Enums

enum MetalTextureType: Int32 {
    case none = 0
    case marker = 1
    case paper = 2
}

enum MetalBlendMode: Int32 {
    case normal = 0
    case multiply = 1
    case screen = 2
    case overlay = 3
}

// MARK: - Extensions

extension Color {
    /// Convert SwiftUI Color to Metal-compatible SIMD float4
    var metalColor: simd_float4 {
        // This is a simplified conversion - would need proper color space handling in production
        let components = self.cgColor?.components ?? [1, 0, 0, 1]
        return simd_float4(
            Float(components[0]),
            Float(components[1]),
            Float(components[2]),
            Float(components.count > 3 ? components[3] : 1.0)
        )
    }
}

// Note: DrawingTool extensions are now in DrawingState.swift

// MARK: - Error Types

enum MetalRendererError: Error {
    case deviceNotAvailable
    case commandQueueCreationFailed
    case shaderLibraryNotFound
    case shaderFunctionNotFound
}

// MARK: - Architecture Notes

/*
 
 ## Design Decisions:
 
 1. **Metal over Core Graphics**: Required for 120Hz and sub-5ms latency
 2. **Command Buffer Architecture**: Enables efficient GPU utilization
 3. **Vertex-based Rendering**: Scalable to complex effects and animations
 4. **Tool-Specific Pipelines**: Each tool can have optimized rendering path
 5. **Performance Monitoring**: Built-in metrics for optimization
 
 ## Performance Targets:
 
 - 120Hz rendering on ProMotion displays
 - <5ms drawing latency (input to pixel)
 - Smooth rendering of 1000+ stroke points
 - Memory efficient for long drawing sessions
 
 ## Future Extensions:
 
 - Layer compositing with blend modes
 - Real-time effects (glow, shadow, texture)
 - Multi-user cursor rendering
 - Screen recording integration
 
 ## Risks & Limitations:
 
 - Metal requires macOS 10.11+ (acceptable for modern app)
 - GPU memory usage scales with drawing complexity
 - Thermal throttling on intensive drawing sessions
 - Compatibility with external GPUs and eGPUs
 
 */
