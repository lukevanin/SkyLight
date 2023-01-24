import UIKit
import AVFoundation

/*
final class LucasKanadeViewController: UIViewController {
    
    private let newImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .systemGreen
        return view
    }()
    
    private let oldImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .systemRed
        return view
    }()
    
    private let ixImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .systemGreen
        return view
    }()
    
    private let iyImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .systemRed
        return view
    }()
    
    private let itImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .systemRed
        return view
    }()

    private let vImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .clear
        view.alpha = 1.0
        return view
    }()

    private let visualizationImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.backgroundColor = .clear
        view.alpha = 1.0
        return view
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private static let ciContext = CIContext(
        options: [
            .cacheIntermediates: false
        ]
    )
        
    private let lucasKanade: LucasKanade
    
    private let videoFileReader: VideoFileReader
    
    private let cvMetalCache: CoreVideoMetalCache
    
    private let sourceSize: MTLSize
    
    private let convertRGB: ImageConversion
    private let convertGray: ImageConversion
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    init() {
        let device = MTLCreateSystemDefaultDevice()!
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        self.sourceSize = MTLSize(width: 360, height: 640, depth: 1)
        self.videoFileReader = VideoFileReader()
        self.lucasKanade = LucasKanade(
            device: device,
            sourceSize: sourceSize,
    //        outputSize: MTLSize(width: 180, height: 320, depth: 1)
            outputSize: MTLSize(width: 90, height: 160, depth: 1)
    //        outputSize: MTLSize(width: 45, height: 80, depth: 1)
    //        outputSize: MTLSize(width: 22, height: 40, depth: 1)
        )
        self.cvMetalCache = CoreVideoMetalCache(device: device)
        self.convertRGB = ImageConversion(device: device, colorSpace: rgbColorSpace)
        self.convertGray = ImageConversion(device: device, colorSpace: grayColorSpace)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        Task {
            let fileURL = Bundle.main.url(forResource: "test-05-480p", withExtension: "mov")!
            await processVideoFile(fileURL: fileURL)
        }
    }
    
    private func setupView() {
        view.backgroundColor = .systemPurple
        
        let imagesLayout0: UIStackView = {
            let layout = UIStackView()
            layout.translatesAutoresizingMaskIntoConstraints = false
            layout.axis = .horizontal
            layout.alignment = .center
            layout.distribution = .equalCentering
            layout.addArrangedSubview(oldImageView)
            layout.addArrangedSubview(newImageView)
            return layout
        }()
        
        let imagesLayout1: UIStackView = {
            let layout = UIStackView()
            layout.translatesAutoresizingMaskIntoConstraints = false
            layout.axis = .horizontal
            layout.alignment = .center
            layout.distribution = .equalCentering
            layout.addArrangedSubview(ixImageView)
            layout.addArrangedSubview(iyImageView)
            layout.addArrangedSubview(itImageView)
            return layout
        }()
        
        let imagesLayout2: UIStackView = {
            let layout = UIStackView()
            layout.translatesAutoresizingMaskIntoConstraints = false
            layout.axis = .horizontal
            layout.alignment = .center
            layout.distribution = .equalCentering
            layout.addArrangedSubview(vImageView)
            layout.addArrangedSubview(visualizationImageView)
            return layout
        }()

        let mainLayout: UIStackView = {
            let layout = UIStackView()
            layout.translatesAutoresizingMaskIntoConstraints = false
            layout.axis = .vertical
            layout.alignment = .fill
            layout.distribution = .equalCentering
            layout.spacing = 4
            layout.addArrangedSubview(imagesLayout0)
            layout.addArrangedSubview(imagesLayout1)
            layout.addArrangedSubview(imagesLayout2)
            return layout
        }()
        
        view.addSubview(mainLayout)
        
        NSLayoutConstraint.activate([
            newImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            newImageView.heightAnchor.constraint(equalTo: newImageView.widthAnchor),
            
            oldImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            oldImageView.heightAnchor.constraint(equalTo: oldImageView.widthAnchor),

            ixImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),
            ixImageView.heightAnchor.constraint(equalTo: ixImageView.widthAnchor),
            
            iyImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),
            iyImageView.heightAnchor.constraint(equalTo: iyImageView.widthAnchor),

            itImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.33),
            itImageView.heightAnchor.constraint(equalTo: itImageView.widthAnchor),
            
            vImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            vImageView.heightAnchor.constraint(equalTo: vImageView.widthAnchor),
            
            visualizationImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            visualizationImageView.heightAnchor.constraint(equalTo: visualizationImageView.widthAnchor),

            mainLayout.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainLayout.widthAnchor.constraint(equalTo: view.widthAnchor),
            
            mainLayout.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    private func processVideoFile(fileURL: URL) async {
        var oldImage: MTLTexture?
        await videoFileReader.readVideoFile(
            fileURL: fileURL,
            sample: { [cvMetalCache, sourceSize, convertRGB, convertGray] sampleBuffer in
                let newImage = cvMetalCache.makeTexture(
                    from: sampleBuffer.imageBuffer!,
                    size: IntegralSize(width: sourceSize.width, height: sourceSize.height)
                )
                if let oldImage = oldImage {
                    lucasKanade.perform(oldImage, newImage)
                    setSnapshot(
                        oldImage: convertRGB.makeCGImage(oldImage),
                        newImage: convertRGB.makeCGImage(newImage),
                        ixImage: convertGray.makeCGImage(lucasKanade.ixTexture),
                        iyImage: convertGray.makeCGImage(lucasKanade.iyTexture),
                        itImage: convertGray.makeCGImage(lucasKanade.itTexture),
                        vImage: convertRGB.makeCGImage(lucasKanade.outputTexture),
                        visualizationImage: makeVisualization(
                            reference: convertRGB.makeCGImage(newImage),
                            vectors: lucasKanade.outputTexture
                        )
                    )
                    await Task.yield()
                }
                oldImage = newImage
            }
        )
    }
    
    @MainActor private func setSnapshot(
        oldImage: CGImage,
        newImage: CGImage,
        ixImage: CGImage,
        iyImage: CGImage,
        itImage: CGImage,
        vImage: CGImage,
        visualizationImage: UIImage
    ) {
        self.oldImageView.image = UIImage(cgImage: oldImage)
        self.newImageView.image = UIImage(cgImage: newImage)
        self.ixImageView.image = UIImage(cgImage: ixImage)
        self.iyImageView.image = UIImage(cgImage: iyImage)
        self.itImageView.image = UIImage(cgImage: itImage)
        self.vImageView.image = UIImage(cgImage: vImage)
        self.visualizationImageView.image = visualizationImage
    }
    
    private func makeVisualization(reference: CGImage, vectors: MTLTexture) -> UIImage {
        
        let inputWidth = vectors.width
        let inputHeight = vectors.height
        
        let outputWidth = sourceSize.width / 2
        let outputHeight = sourceSize.height / 2
        let grid = 5
        let scale = Float32(20)
        
        let backgroundColor = UIColor.systemGreen.withAlphaComponent(0.5)
        let zoneColor = UIColor.white.withAlphaComponent(0.5)
        let lineColor = UIColor.systemPink

        
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: inputWidth, height: inputHeight, depth: 1)
        )
        let bytesPerComponent = MemoryLayout<simd_packed_float2>.stride
        let bytesPerRow = bytesPerComponent * inputWidth
        // let totalBytes = bytesPerRow * texture.height

        var textureData = Array<simd_packed_float2>(
            repeating: simd_packed_float2.zero,
            count: inputWidth * inputHeight
        )
        vectors.getBytes(
            &textureData,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )
        

        let size = CGSize(width: outputWidth, height: outputHeight)
        let bounds = CGRect(origin: .zero, size: size)
        
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let imageRenderer = UIGraphicsImageRenderer(
            bounds: bounds,
            format: format
        )
        let image = imageRenderer.image { context in
            
            let cgContext = context.cgContext
            cgContext.setShouldAntialias(false)
            cgContext.setAllowsAntialiasing(false)
            
            cgContext.saveGState()
            cgContext.scaleBy(x: 1, y: -1)
            cgContext.translateBy(x: 0, y: -size.height)
            cgContext.draw(reference, in: bounds)
            cgContext.restoreGState()
            
            cgContext.saveGState()
            cgContext.setFillColor(backgroundColor.cgColor)
            cgContext.fill([bounds])
            cgContext.restoreGState()
            
//            let sx = inputWidth / grid
//            let sy = inputHeight / grid
            
            let k = 5
            let minX: Int = k
            let minY: Int = k
            let maxX: Int = inputWidth - 1 - k
            let maxY: Int = inputHeight - 1 - k
            let deltaX = maxX - minX
            let deltaY = maxY - minY
            
            let scaleX = Float(outputWidth) / Float(inputWidth)
            let scaleY = Float(outputHeight) / Float(inputHeight)
            
            var aDirection = simd_float2(0, 0)
            var aCount = 0

            for j in 0 ..< grid {
                
                for i in 0 ..< grid {
                    
                    let ox = Float(minX) + ((Float(i) / Float(grid)) * Float(deltaX))
                    let oy = Float(minY) + ((Float(j) / Float(grid)) * Float(deltaY))
                    
                    var direction = simd_float2(0, 0)
                    var count = Float(0)
                    
                    for v in -k ... +k {
                        
                        for u in -k ... +k {
                            
                            let dx = Int((ox + Float(u)).rounded())
                            let dy = Int((oy + Float(v)).rounded())
                            
                            let offset = (dy * inputWidth) + dx
                            direction += textureData[offset]
                            count += 1
                        }
                    }
                    
                    direction = direction / count
                    let length = simd_length(direction)
                    
                    guard length > 0.0001 else {
                        continue
                    }

                    aDirection += direction
                    aCount += 1

//                    print("flow", "dx", dx, "dy", dy, "=", length)
//                    let vector = (simd_normalize(direction) * 2) +
                    let vector = direction * scale

                    let origin = simd_packed_float2(
                        x: (ox * scaleX).rounded(),
                        y: (oy * scaleY).rounded()
                    )
                    let start = CGPoint(origin)
                    let end = CGPoint(origin + vector)
                    

                    cgContext.saveGState()
                    cgContext.setFillColor(zoneColor.cgColor)
                    cgContext.fillEllipse(
                        in: CGRect(
                            x: CGFloat(origin.x) - (CGFloat(scale) * 0.5),
                            y: CGFloat(origin.y) - (CGFloat(scale) * 0.5),
                            width: CGFloat(scale),
                            height: CGFloat(scale)
                        )
                    )
                    cgContext.restoreGState()

                    cgContext.saveGState()
                    cgContext.move(to: start)
                    cgContext.addLine(to: end)
                    cgContext.setLineWidth(5)
                    cgContext.setStrokeColor(lineColor.cgColor)
                    cgContext.strokePath()
                    cgContext.restoreGState()

                    // let percent = Double((y * sx) + x) / Double(sx * sy)
                    // print(String(format: "%0.3f%% %0.3f %0.3f %0.3f", percent * 100, direction.x, direction.y, length))
                }
            }
            
            let radius = Float(100)
            let center = CGPoint(
                x: CGFloat(outputWidth) * 0.5,
                y: CGFloat(outputHeight) * 0.5
            )
            let heading = CGPoint((aDirection / Float(aCount)) * radius)
            let end = CGPoint(
                x: center.x + heading.x,
                y: center.y + heading.y
            )
            
            cgContext.saveGState()
            cgContext.setFillColor(zoneColor.cgColor)
            cgContext.fillEllipse(
                in: CGRect(
                    x: center.x - CGFloat(radius),
                    y: center.y - CGFloat(radius),
                    width: CGFloat(radius) * 2,
                    height: CGFloat(radius) * 2
                )
            )
            cgContext.restoreGState()

            cgContext.saveGState()
            cgContext.move(to: center)
            cgContext.addLine(to: end)
            cgContext.setLineWidth(5)
            cgContext.setStrokeColor(lineColor.cgColor)
            cgContext.strokePath()
            cgContext.restoreGState()

        }
        
        return image
    }
    }
 
 */

