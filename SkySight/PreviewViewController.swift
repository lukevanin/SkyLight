import UIKit
import simd
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import AVFoundation
import MetalPerformanceShaders


final class PreviewViewController: UIViewController {
    
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
        
    private var imageRequestHandler: VNImageRequestHandler?
    
    private let sequenceRequestHandler: VNSequenceRequestHandler = {
        let handler = VNSequenceRequestHandler()
        return handler
    }()
    
    private let lucasKanade: LucasKanade = LucasKanade(
        sourceSize: MTLSize(width: 360, height: 640, depth: 1),
//        outputSize: MTLSize(width: 180, height: 320, depth: 1)
        outputSize: MTLSize(width: 90, height: 160, depth: 1)
//        outputSize: MTLSize(width: 45, height: 80, depth: 1)
//        outputSize: MTLSize(width: 22, height: 40, depth: 1)
    )
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    init() {
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
//        updateImages()
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
        let asset = AVURLAsset(url: fileURL)
        let reader = try! AVAssetReader(asset: asset)
        let videoTrack = reader.asset.tracks(withMediaType: .video).first!
        let videoTrackTimeRange = try! await videoTrack.load(.timeRange)
        let videoTrackOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String: true,
//                AVVideoScalingModeKey: AVVideoScalingModeResize,
//                AVVideoCleanApertureKey: [
//                    AVVideoCleanApertureWidthKey: NSNumber(value: 1080.0 * 0.25),
//                    AVVideoCleanApertureHeightKey: NSNumber(value: 1920.0 * 0.25)
//                ]
            ]
        )
        videoTrackOutput.supportsRandomAccess = false
        //videoTrackOutput.reset(forReadingTimeRanges: [NSValue(timeRange: videoTrackTimeRange)])
        videoTrackOutput.markConfigurationAsFinal()
        reader.add(videoTrackOutput)

        print(
            "reading time range",
            String(format: "%0.2f", videoTrackTimeRange.start.seconds),
            "-",
            String(format: "%0.2f", videoTrackTimeRange.end.seconds)
        )
        reader.startReading()
        var count = 0
        var oldImage: CVImageBuffer?
        var oldTime = CFAbsoluteTimeGetCurrent()
        while let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
            let newTime = CFAbsoluteTimeGetCurrent()
            print(
                "read sample",
                count,
                "at",
                String(format: "%0.2f", sampleBuffer.presentationTimeStamp.seconds),
                "/",
                String(format: "%0.2f", videoTrackTimeRange.end.seconds),
                "@",
                String(format: "%0.3f", newTime - oldTime),
                "seconds"
            )
            count += 1
//            guard count % 10 == 0 else {
//                continue
//            }
            let newImage = sampleBuffer.imageBuffer!
            if let oldImage = oldImage {
//                opticalFlowLucasKanade(oldImage, newImage)
                let snapshot = lucasKanade.perform(oldImage, newImage)
                setSnapshot(snapshot)
                await Task.yield()
            }
            oldImage = newImage
            oldTime = newTime

            // try! await Task.sleep(nanoseconds: UInt64(1e9 * 0.2))
        }
    }
    
    @MainActor private func setSnapshot(_ snapshot: Snapshot) {
        self.oldImageView.image = UIImage(cgImage: snapshot.oldImage)
        self.newImageView.image = UIImage(cgImage: snapshot.newImage)
        self.ixImageView.image = UIImage(cgImage: snapshot.ixImage)
        self.iyImageView.image = UIImage(cgImage: snapshot.iyImage)
        self.itImageView.image = UIImage(cgImage: snapshot.itImage)
        self.vImageView.image = UIImage(cgImage: snapshot.vImage)
        self.visualizationImageView.image = snapshot.visualizationImage
    }

    /*
    private func updateImages() {
        let referenceImage = UIImage(named: "image-a0")!
        let floatingImage = UIImage(named: "image-a1")!
        oldImageView.image = referenceImage
        newImageView.image = floatingImage
        
        let referenceCIImage = CIImage(image: referenceImage)!
        let floatingCIImage = CIImage(image: floatingImage)!

        opticalFlow(
            referenceImage: referenceCIImage,
            floatingImage: floatingCIImage
        )
        
        return
        
//        let homographicCIImage = homographicRegistration(
//            referenceImage: referenceCIImage,
//            floatingImage: floatingCIImage
//        )
//
//        guard let homographicCIImage = homographicCIImage else {
//            return
//        }
        
        let translatedCIImage = translationalRegistration(
            referenceImage: referenceCIImage,
            floatingImage: floatingCIImage
//            floatingImage: homographicCIImage
        )

        guard let translatedCIImage = translatedCIImage else {
            return
        }

//        let warpedCIImage = translatedCIImage

        let compositeFilter = CIFilter.additionCompositing()
//        let compositeFilter = CIFilter.sourceOverCompositing()
//        let compositeFilter = CIFilter.subtractBlendMode()
        compositeFilter.backgroundImage = referenceCIImage
        compositeFilter.inputImage = translatedCIImage
        let compositeCIImage = compositeFilter.outputImage!

        let compositeCGImage = ciContext.createCGImage(compositeCIImage, from: compositeCIImage.extent)!

        previewImageView.image = UIImage(cgImage: compositeCGImage)
    }
     */

    /*
    private func opticalFlowSequence(referenceImage: CVPixelBuffer, floatingImage: CVPixelBuffer) {
        
        let referenceCIImage = CIImage(cvPixelBuffer: referenceImage, options: [.applyOrientationProperty: true])
        
        let request = VNGenerateOpticalFlowRequest(
            targetedCVPixelBuffer: floatingImage,
            completionHandler: { [weak self] request, error in
                guard let result = request.results?.first else {
                    print("Cannot perform request. Reason:", error?.localizedDescription ?? "- unknown -")
                    return
                }
                let observation = result as! VNPixelBufferObservation
                let image = Self.makeOpticalFlowImage(
                    referenceImage: referenceCIImage,
                    buffer: observation.pixelBuffer
                )
                DispatchQueue.main.async {
                    self?.previewImageView.image = image
                }
            }
        )
        request.computationAccuracy = .low
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
        request.preferBackgroundProcessing = false
        request.usesCPUOnly = false
        request.regionOfInterest = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        
        try! sequenceRequestHandler.perform([request], on: referenceImage)
    }
    
    private func opticalFlow(referenceImage: CIImage, floatingImage: CIImage) {
        
        let request = VNGenerateOpticalFlowRequest(
            targetedCIImage: referenceImage
        )
        request.computationAccuracy = .high
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
        
        imageRequestHandler = VNImageRequestHandler(
            ciImage: floatingImage
        )
        try! imageRequestHandler?.perform([request])
        
        guard let results = request.results else {
            print("No results")
            return
        }
        
        guard let result = results.first else {
            print("No result")
            return
        }

        print("results", result)
        let image = Self.makeOpticalFlowImage(
            referenceImage: referenceImage,
            buffer: result.pixelBuffer
        )
        previewImageView.image = image
    }
    
    private static func makeOpticalFlowImage(referenceImage: CIImage, buffer: CVPixelBuffer) -> UIImage {
        
        let referenceCGImage = ciContext.createCGImage(referenceImage, from: referenceImage.extent)!
        
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
        precondition(pixelFormat == kCVPixelFormatType_TwoComponent32Float)
        let bytesPerComponent = MemoryLayout<simd_packed_float2>.stride
        precondition(bytesPerComponent == (4 * 2))
        
        let isPlanar = CVPixelBufferIsPlanar(buffer)
        precondition(isPlanar == false)
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let address = CVPixelBufferGetBaseAddress(buffer)!
        
        let size = CGSize(width: width, height: height)
        let bounds = CGRect(origin: .zero, size: size)
        let grid = 50
        
        let scale = Float32(1)
        let backgroundColor = UIColor.black.withAlphaComponent(0.3)
        let lineColor = UIColor.systemPink
        
        let imageRenderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = imageRenderer.image { context in
            
            let cgContext = context.cgContext
            
            cgContext.saveGState()
            cgContext.scaleBy(x: 1, y: -1)
            cgContext.translateBy(x: 0, y: -bounds.height)
            cgContext.draw(referenceCGImage, in: bounds)
            cgContext.restoreGState()
            
            cgContext.setFillColor(backgroundColor.cgColor)
            cgContext.fill(bounds)
            
            let sx = width / grid
            let sy = height / grid
            
            for y in 0 ..< sy {
                
                for x in 0 ..< sx {
                    
                    let dx = x * grid
                    let dy = y * grid
                    let origin = simd_packed_float2(x: Float32(dx), y: Float32(dy))
                    
                    let offset = (dy * bytesPerRow) + (dx * bytesPerComponent)
                    let pointer = address.advanced(by: offset).assumingMemoryBound(to: simd_packed_float2.self)
                    let direction = pointer.pointee
                    let vector = direction * scale
                    let length = simd_length(direction)
                    
//                    guard length < 1000 else {
//                        continue
//                    }
                    
                    let start = CGPoint(origin)
                    let end = CGPoint(origin + vector)
                    
                    cgContext.move(to: start)
                    cgContext.addLine(to: end)
                    
                    let percent = Double((y * sx) + x) / Double(sx * sy)
                    // print(String(format: "%0.3f%% %0.3f %0.3f %0.3f", percent * 100, direction.x, direction.y, length))
                }
            }
            
            cgContext.setLineWidth(3)
            cgContext.setStrokeColor(lineColor.cgColor)
            cgContext.strokePath()
        }

        return image
    }

    private func homographicRegistration(referenceImage: CIImage, floatingImage: CIImage) -> CIImage? {
        // TODO: Use camera intrinsics
        
        let request = VNHomographicImageRegistrationRequest(
            targetedCIImage: floatingImage
        )
        
        // TODO: Use VNSequenceRequestHandler
        imageRequestHandler = VNImageRequestHandler(
            ciImage: referenceImage
        )
        
        do {
            try imageRequestHandler?.perform([request])
        }
        catch {
            print("Cannot process image request: \(error.localizedDescription)")
            return nil
        }
        
        guard let results = request.results else {
            return nil
        }
        
        print("Image processing results")
        for result in results {
            print(result, result.warpTransform)
        }
        
        guard let result = results.first else {
            return nil
        }
        
        let warpedImage = floatingImage.perspectiveTransformed(
            by: result.warpTransform
        )

        return warpedImage
    }

    private func translationalRegistration(referenceImage: CIImage, floatingImage: CIImage) -> CIImage? {
        // TODO: Use camera intrinsics
        let request = VNTranslationalImageRegistrationRequest(
            targetedCIImage: floatingImage
        )
//        request.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1).insetBy(dx: 0.1, dy: 0.1)

        // TODO: Use VNSequenceRequestHandler
        imageRequestHandler = VNImageRequestHandler(
            ciImage: referenceImage
        )

        do {
            try imageRequestHandler?.perform([request])
        }
        catch {
            print("Cannot process image request: \(error.localizedDescription)")
            return nil
        }

        guard let results = request.results else {
            return nil
        }

        print("Image processing results")
        for result in results {
            print(result, result.alignmentTransform)
        }

        guard let result = results.first else {
            return nil
        }

        let warpedImage = floatingImage.transformed(
            by: result.alignmentTransform
        )
        return warpedImage
    }
    */
}

