//
//  SIFTViewController.swift
//  SkySight
//
//  Created by Luke Van In on 2022/12/18.
//

import UIKit


@globalActor actor ProcessActor {
    static let shared = ProcessActor()
}


private func makeImageView() -> UIImageView {
    let view = UIImageView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.contentMode = .scaleAspectFit
    view.isOpaque = true
    view.backgroundColor = .green
    return view
}


final class SIFTViewController: UIViewController {
    
    private let inputImageView: UIImageView
    
    private let scaleImageViews: [UIImageView]
    
    private let sift: SIFT
    
    private let videoFileURL: URL
    private let videoSize: IntegralSize
    
    private let videoReader: VideoFileReader
    private let cvMetalCache: CoreVideoMetalCache
    private let imageConverter: ImageConversion

    init() {
        let octaves = 4
        let extrema = 2
        let device = MTLCreateSystemDefaultDevice()!
        self.videoSize = IntegralSize(width: 360, height: 640)
        let sift = SIFT(
            device: device,
            configuration: SIFT.Configuration(inputSize: videoSize)
        )
        self.videoFileURL = Bundle.main.url(forResource: "test-03-480p", withExtension: "mov")!
        self.cvMetalCache = CoreVideoMetalCache(device: device)
        self.videoReader = VideoFileReader()
        self.sift = sift
        self.imageConverter = ImageConversion(device: device, colorSpace: CGColorSpaceCreateDeviceGray())
        self.inputImageView = makeImageView()
        self.scaleImageViews = {
            var views = [UIImageView]()
//            for octave in sift.octaves {
//                for _ in 0 ..< octave.gaussianCount {
//                    let view = makeImageView()
//                    views.append(view)
//                }
//            }
            return views
        }()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupView()
        processVideo()
    }
    
    private func setupView() {
        view.backgroundColor = .systemCyan
        
        let layoutView: UIStackView = {
            let view = UIStackView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.axis = .vertical
            view.alignment = .center
            view.spacing = 16
            view.addArrangedSubview(inputImageView)
            for scaleImageView in scaleImageViews {
                view.addArrangedSubview(scaleImageView)
            }
            return view
        }()

        let scrollView: UIScrollView = {
            let view = UIScrollView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(layoutView)
            return view
        }()
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            layoutView.widthAnchor.constraint(equalTo: view.widthAnchor),
            layoutView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            layoutView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            layoutView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            layoutView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func processVideo() {
        Task { [weak self] in
            guard let self = self else {
                return
            }
            await self.processVideoFile(fileURL: self.videoFileURL)
        }
    }
    
    private func processVideoFile(fileURL: URL) async {
        await videoReader.readVideoFile(
            fileURL: fileURL,
            sample: { [unowned self] sample in
                await self.processSample(sample.imageBuffer!)
            }
        )
    }
    
    @ProcessActor private func processSample(_ imageBuffer: CVImageBuffer) async {
        let newTexture = cvMetalCache.makeTexture(
            from: imageBuffer,
            size: videoSize
        )
        sift.getKeypoints(newTexture)
//        await self.updateViews(
//            inputImage: imageConverter.makeCGImage(sift.inputTexture),
//            scaleImages: sift.octaves.flatMap { octave in
//                octave.gaussianTextures.map { texture in
////                    imageConverter.makeCGImage(CIImage(mtlTexture: texture)!.colorInverted())
//                    imageConverter.makeCGImage(CIImage(mtlTexture: texture)!)
//                }
//            }
//        )
    }
    
    @MainActor private func updateViews(
        inputImage: CGImage,
        scaleImages: [CGImage]
    ) {
        inputImageView.image = UIImage(cgImage: inputImage)
        for i in 0 ..< scaleImages.count {
            scaleImageViews[i].image = UIImage(cgImage: scaleImages[i])
        }
    }
}
