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
            ]
        )
        videoTrackOutput.supportsRandomAccess = false
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
}

