//
//  SIFTViewController.swift
//  SkyLight
//
//  Created by Luke Van In on 2022/12/18.
//

import UIKit
import MetalKit

import SIFTMetal


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


private func makeNames(withPrefix p: String, andExtension e: String, inRange r: CountableClosedRange<Int>) -> [String] {
    var output = [String]()
    for i in r {
        let name = "\(p)\(i).\(e)"
        output.append(name)
    }
    return output
}


final class MatchView: UIView {
    
    let sourceImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.backgroundColor = .systemPink
        view.alpha = 0.8
        return view
    }()
    
    let targetImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.backgroundColor = .systemTeal
        view.alpha = 0.8
        return view
    }()

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let layoutView: UIStackView = {
            let view = UIStackView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.axis = .vertical
            view.alignment = .fill
            view.spacing = 8
            view.addArrangedSubview(sourceImageView)
            view.addArrangedSubview(targetImageView)
            view.addArrangedSubview(label)
            return view
        }()
        
        addSubview(layoutView)
        
        NSLayoutConstraint.activate([
            sourceImageView.heightAnchor.constraint(equalTo: sourceImageView.widthAnchor),
            targetImageView.heightAnchor.constraint(equalTo: targetImageView.widthAnchor),

            layoutView.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
            layoutView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
            layoutView.topAnchor.constraint(equalTo: topAnchor),
            layoutView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class SIFTViewController: UIViewController {
    
    struct ImageDescriptor {
        let name: String
        let image: CGImage
        let features: [FloatVector]
    }
    
    struct ImageBagOfWords {
        let name: String
        let image: CGImage
        let bagOfWords: FloatVector
    }
    
    struct ImageMatch {
        let source: ImageBagOfWords
        let target: ImageBagOfWords
        let distance: Float
    }
    
    private let layoutView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 16
        return view
    }()

    
    private var imageDimensions: IntegralSize!
    private var sift: SIFT!
    private var kmeans: KMeansCluster!
    private var resizer: ImageResizer!
    
//    private let videoFileURL: URL
//    private let videoSize: IntegralSize
    private let imageFileURL: URL
    
    private var videoReader: VideoFileReader!
//    private var cvMetalCache: CoreVideoMetalCache!
    private var imageConverter: ImageConversion!
    private var device: MTLDevice!

    init() {
        device = MTLCreateSystemDefaultDevice()!

//        self.videoSize = IntegralSize(width: 360, height: 640)
//        self.videoFileURL = Bundle.main.url(forResource: "test-05-480p", withExtension: "mov")!
        self.imageFileURL = Bundle.main.url(forResource: "butterfly", withExtension: "png")!
//        self.cvMetalCache = CoreVideoMetalCache(device: device)
//        self.videoReader = VideoFileReader()
//        self.sift = sift
        self.imageConverter = ImageConversion(
            device: device,
            colorSpace: CGColorSpaceCreateDeviceGray()
        )
//        self.inputImageView = makeImageView()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupView()
        processImages()
    }
    
    private func setupView() {
        view.backgroundColor = .systemPurple
        
        let scrollView: UIScrollView = {
            let view = UIScrollView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.alwaysBounceVertical = true
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
    
    private func processImages() {
        Task.detached {
            await self.matchImages()
        }
    }
    
    private func matchImages() {
        // Load SIFT descriptors
        let referencePlaces = makeNames(
            withPrefix: "reference-01 - ",
            andExtension: "jpeg",
            inRange: 1...20
        )
        
        let testImageNames = makeNames(
            withPrefix: "trajectory-01 - ",
            andExtension: "jpeg",
            inRange: 1...10
        )
        
        imageDimensions = IntegralSize(
            width: 192 * 2,
            height: 256 * 2
        )
        
        resizer = ImageResizer(device: device)
        
        let configuration = SIFT.Configuration(inputSize: imageDimensions)
        sift = SIFT(device: device, configuration: configuration)

        let referenceDescriptors = try! loadReferenceImages(names: referencePlaces)
        
//        for descriptor in referenceDescriptors {
//            print(descriptor.name)
//            for i in 0 ..< descriptor.descriptors.count {
//                let features = descriptor.descriptors[i].rawFeatures().standardized()
//                print("descriptor \(i)", features)
//            }
//        }
        
        let referenceVectors = referenceDescriptors
            .map { $0.features }
            .joined()
//            .map { $0.rawFeatures().standardized() }
//            .map { $0.rawFeatures().standardized() }

        kmeans = KMeansCluster(k: 130, d: 16)
        kmeans.train(
            vectors: Array(referenceVectors),
            maximumIterations: 50,
            maximumError: 0.001
        )
        
        var referenceBagOfWords = [ImageBagOfWords]()
        for reference in referenceDescriptors {
            let descriptors = reference.features
            guard let bagOfWords = kmeans.bagOfWords(for: descriptors) else {
                continue
            }
            let imageBagOfWords = ImageBagOfWords(
                name: reference.name,
                image: reference.image,
                bagOfWords: bagOfWords
            )
            print("reference:", reference.name, "bag of words:", bagOfWords)
            referenceBagOfWords.append(imageBagOfWords)
        }

        /*
        bag of words <Vector [10] 0, 0, 0, 14, 10, 3, 21, 0, 1, 0>
        reference: reference-01 - 6.jpeg <Vector [10] 0, 0, 0, 14, 10, 3, 21, 0, 1, 0>
        
        bag of words <Vector [10] 18, 7, 6, 6, 4, 8, 9, 16, 3, 0>
         */
        
        for sourceImageName in testImageNames {
            
            let sourceImage = try! loadImage(sourceImageName)
            guard let sourceDescriptor = makeDescriptor(
                sift: sift,
                name: sourceImageName,
                texture: sourceImage
            ) else {
                continue
            }
            let features = sourceDescriptor.features
            guard let bagOfWords = kmeans.bagOfWords(for: features) else {
                continue
            }
            let source = ImageBagOfWords(
                name: sourceImageName,
                image: imageConverter.makeCGImage(sourceImage),
                bagOfWords: bagOfWords
            )
            print("sample:", source.name, source.bagOfWords)

//            var minimumDistance: Float = .greatestFiniteMagnitude
            var maximumSimilarity: Float = -.greatestFiniteMagnitude
            var match: ImageMatch!
            
            for target in referenceBagOfWords {

                let similarity = source.bagOfWords.cosineSimilarity(to: target.bagOfWords)
                print("matching \(target.name) similarity=\(similarity)")
                if similarity > maximumSimilarity {
                    maximumSimilarity = similarity
                    match = ImageMatch(
                        source: source,
                        target: target,
                        distance: similarity
                    )
                }

//                let distance = source.bagOfWords.distance(to: target.bagOfWords)
//                print("matching \(target.name) distance=\(distance)")
//                if distance < minimumDistance {
//                    minimumDistance = distance
//                    match = ImageMatch(
//                        source: source,
//                        target: target,
//                        distance: distance
//                    )
//                }

//                var matches = [SIFTCorrespondence]()
//                for descriptor in imageDescriptors.descriptors {
//                    let match = SIFTDescriptor.match(
//                        descriptor: descriptor,
//                        target: imageIndex.index
//                    )
//                    guard let match else {
//                        continue
//                    }
//                    matches.append(match)
//                }
//
//                print("Found \(matches.count) matches")
                
//                let imageMatch = ImageMatches(
//                    image: imageDescriptors.image,
//                    matches: matches
//                )
//                imageMatches.append(imageMatch)
                
//                let keypoints = imageMatch.matches.map { correspondence in
//                    correspondence.source.keypoint
//                }
//                let keypointImage = renderer.drawKeypoints(
//                    sourceImage: imageMatch.image,
//                    overlayColor: UIColor.black.withAlphaComponent(0.5),
//                    referenceKeypoints: [],
//                    foundKeypoints: keypoints
//                )
                
            }
            
            let outputMatch = match!
            Task.detached { @MainActor in
                self.addImageMatch(match: outputMatch)
            }
        }
    }
    
    @MainActor private func addImageMatch(match: ImageMatch) {
        let matchView: MatchView = {
            let view = MatchView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.sourceImageView.image = UIImage(cgImage: match.source.image)
            view.targetImageView.image = UIImage(cgImage: match.target.image)
            view.label.text = "\(match.distance)"
            return view
        }()
        layoutView.addArrangedSubview(matchView)
        
        //
//        let imageSize = IntegralSize(width: 512, height: 340)
//        let sift = SIFT(
//            device: device,
//            configuration: SIFT.Configuration(inputSize: imageSize)
//        )
//
//        self.device = device
//        self.sift = sift
//
//        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 2) { [weak self] in
//            self?.processImage()
//        }

    }
    
    private func loadReferenceImages(names: [String]) throws -> [ImageDescriptor] {
        var output: [ImageDescriptor] = []
        for name in names {
            guard let imageDescriptor = try loadDescriptor(name: name) else {
                continue
            }
            output.append(imageDescriptor)
        }
        precondition(!output.isEmpty)
        return output
    }
    
    private func loadDescriptor(name: String) throws -> ImageDescriptor? {
        let texture = try loadImage(name)
        let dimensions = IntegralSize(
            width: texture.width,
            height: texture.height
        )
        let configuration = SIFT.Configuration(inputSize: dimensions)
        let sift = SIFT(device: device, configuration: configuration)
        return makeDescriptor(
            sift: sift,
            name: name,
            texture: texture
        )
    }
    
    private func loadImage(_ name: String) throws -> MTLTexture {
        print("Loading reference image: \(name)")
        let path = "Sample Data/\(name)"
        let imageURL = Bundle.main.bundleURL.appending(path: path)
        let loader = MTKTextureLoader(device: device)
        let texture = try! loader.newTexture(
            URL: imageURL,
            options: [
                .SRGB: NSNumber(value: false),
            ]
        )
        
        return resizer.resizeTexture(
            texture: texture,
            width: imageDimensions.width,
            height: imageDimensions.height
        )
    }
    
    private func makeDescriptor(
        sift: SIFT,
        name: String,
        texture: MTLTexture
    ) -> ImageDescriptor? {
        let keypointOctaves = sift.getKeypoints(texture)
//        print("Loaded \(keypointOctaves.joined().count) descriptors")
        let descriptorOctaves = sift.getDescriptors(keypointOctaves: keypointOctaves)
        let descriptors = Array(descriptorOctaves.joined())
//        let vectors = descriptors.map { $0.rawFeatures() }
        print("\(name) loaded \(descriptors.count) descriptors")
        guard !descriptors.isEmpty else {
            print("❗️ \(name) SKIPPED")
            return nil
        }
        let features = descriptors
            .map {
//                var features = [FloatVector]()
                var features = [Float]()
                let rawFeatures = $0.rawFeatures().components
                let chunkSize = 8
                for i in stride(from: 0, to: rawFeatures.count, by: chunkSize) {
                    let feature = Array(rawFeatures[i ..< i + chunkSize])
//                    print(feature)
//                    features.append(feature)
                    
                    var sum: Float = 0
                    for f in feature {
                        sum += f
                    }
                    let a = sum / Float(chunkSize)
                    features.append(a)
                }
                precondition(features.count == 16, "No features in descriptor: \(rawFeatures)")
                return FloatVector(features)
            }
        guard !features.isEmpty else {
            print("❗️ \(name) SKIPPED")
            return nil
        }
//        precondition(!features.isEmpty, "No features \(features) for descriptors: \(descriptors)")
        return ImageDescriptor(
            name: name,
            image: imageConverter.makeCGImage(texture),
            features: Array(features)
        )
    }
    
//    private func processVideo() {
//        Task { [weak self] in
//            guard let self = self else {
//                return
//            }
//            await self.processVideoFile(fileURL: self.videoFileURL)
//        }
//    }
    
//    private func processVideoFile(fileURL: URL) async {
//        await videoReader.readVideoFile(
//            fileURL: fileURL,
//            sample: { [unowned self] sample in
//                await self.processSample(sample.imageBuffer!)
//            }
//        )
//    }
    
//    @ProcessActor private func processSample(_ imageBuffer: CVImageBuffer) async {
//        let newTexture = cvMetalCache.makeTexture(
//            from: imageBuffer,
//            size: videoSize
//        )
//        sift.getKeypoints(newTexture)
//        await self.updateViews(
//            inputImage: imageConverter.makeCGImage(sift.inputTexture),
//            scaleImages: sift.octaves.flatMap { octave in
//                octave.gaussianTextures.map { texture in
////                    imageConverter.makeCGImage(CIImage(mtlTexture: texture)!.colorInverted())
//                    imageConverter.makeCGImage(CIImage(mtlTexture: texture)!)
//                }
//            }
//        )
//    }
    
//    private func processImage() {
//        Task { [weak self] in
//            guard let self = self else {
//                return
//            }
//            self.processImageFile()
//        }
//    }
    
//    private func processImageFile() {
//        let loader = MTKTextureLoader(device: device)
//        let texture = try! loader.newTexture(
//            URL: self.imageFileURL,
//            options: [
//                .SRGB: NSNumber(value: false),
//            ]
//        )
//        let startTime = CFAbsoluteTimeGetCurrent()
//        print("Finding keypoints")
//        let keypoints = sift.getKeypoints(texture)
//        print("Found \(keypoints.joined().count) keypoints")
//        print("Finding descriptors")
//        let descriptors = sift.getDescriptors(keypointOctaves: keypoints)
//        print("Found \(descriptors.joined().count) descriptors")
//        let endTime = CFAbsoluteTimeGetCurrent()
//        let elapsedTime = endTime - startTime
//        print("Time: \(elapsedTime) seconds")
//    }
    
//    @MainActor private func updateViews(
//        inputImage: CGImage,
//        scaleImages: [CGImage]
//    ) {
//        inputImageView.image = UIImage(cgImage: inputImage)
//        for i in 0 ..< scaleImages.count {
//            scaleImageViews[i].image = UIImage(cgImage: scaleImages[i])
//        }
//    }
}
