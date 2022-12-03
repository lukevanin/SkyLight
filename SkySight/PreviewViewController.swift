import UIKit
import simd
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision


struct Quad {
    var topLeft: simd_float2
    var topRight: simd_float2
    var bottomRight: simd_float2
    var bottomLeft: simd_float2

    var points: [simd_float2] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }
    
    func transformed(by matrix: simd_float3x3) -> Quad {
        Quad(
            points: points
                .map { point in
                    simd_float3(point.x, point.y, 1)
                }
                .map { point in
                    matrix * point
                }
                .map { point in
                    simd_float2(point.x / point.z, point.y / point.z)
                }
        )
    }
}

extension Quad {
    init(rect: CGRect) {
        self.init(
            topLeft: simd_float2(Float(rect.minX), Float(rect.maxY)),
            topRight: simd_float2(Float(rect.maxX), Float(rect.maxY)),
            bottomRight: simd_float2(Float(rect.maxX), Float(rect.minY)),
            bottomLeft: simd_float2(Float(rect.minX), Float(rect.minY))
        )
    }
    
    init(points: [simd_float2]) {
        self.init(
            topLeft: points[0],
            topRight: points[1],
            bottomRight: points[2],
            bottomLeft: points[3]
        )
    }
}


extension CGPoint {
    init(_ point: simd_float2) {
        self.init(x: CGFloat(point.x), y: CGFloat(point.y))
    }
}

extension CIImage {
    func perspectiveTransformed(by matrix: simd_float3x3) -> CIImage {
        let bounds = Quad(rect: extent).transformed(by: matrix)
        let filter = CIFilter.perspectiveTransform()
        filter.topLeft = CGPoint(bounds.topLeft)
        filter.topRight = CGPoint(bounds.topRight)
        filter.bottomRight = CGPoint(bounds.bottomRight)
        filter.bottomLeft = CGPoint(bounds.bottomLeft)
        filter.inputImage = self
        return filter.outputImage!
    }
}


final class PreviewViewController: UIViewController {
    
    private let newImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .systemGreen
        return view
    }()
    
    private let oldImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .systemRed
        return view
    }()
    
    private let backgroundImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .systemCyan
        view.alpha = 1.0
        return view
    }()

    private let previewImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        view.alpha = 1.0
        return view
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let ciContext = CIContext(
        options: [
            .cacheIntermediates: false
        ]
    )
    
    private var imageRequestHandler: VNImageRequestHandler?
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        updateImages()
    }
    
    private func setupView() {
        view.backgroundColor = .systemPurple
        
        let imagesLayout: UIStackView = {
            let layout = UIStackView()
            layout.translatesAutoresizingMaskIntoConstraints = false
            layout.axis = .horizontal
            layout.alignment = .center
            layout.distribution = .equalSpacing
            layout.addArrangedSubview(oldImageView)
            layout.addArrangedSubview(newImageView)
            return layout
        }()
        
        let mainLayout: UIStackView = {
            let layout = UIStackView()
            layout.translatesAutoresizingMaskIntoConstraints = false
            layout.axis = .vertical
            layout.alignment = .center
            layout.distribution = .equalSpacing
            layout.spacing = 16
            layout.addArrangedSubview(imagesLayout)
            layout.addArrangedSubview(containerView)
            return layout
        }()
        
        containerView.addSubview(backgroundImageView)
        containerView.addSubview(previewImageView)
        view.addSubview(mainLayout)
        
        NSLayoutConstraint.activate([
            newImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            newImageView.heightAnchor.constraint(equalTo: newImageView.widthAnchor),
            
            oldImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
            oldImageView.heightAnchor.constraint(equalTo: oldImageView.widthAnchor),
            
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor),
            
            backgroundImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            backgroundImageView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            backgroundImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            backgroundImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor),
            
            previewImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            previewImageView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            previewImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            previewImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor),

            mainLayout.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainLayout.widthAnchor.constraint(equalTo: view.widthAnchor),
            
            mainLayout.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func updateImages() {
        let referenceImage = UIImage(named: "image-d0")
        let floatingImage = UIImage(named: "image-d1")
        oldImageView.image = referenceImage
        newImageView.image = floatingImage
        
        guard let referenceImage = referenceImage else {
            return
        }
        guard let floatingImage = floatingImage else {
            return
        }
        
        guard let referenceCIImage = CIImage(image: referenceImage) else {
            return
        }
        
        guard let floatingCIImage = CIImage(image: floatingImage) else {
            return
        }

        // TODO: Use camera intrinsics
        let request = VNHomographicImageRegistrationRequest(
            targetedCIImage: floatingCIImage
        )
        
        // TODO: Use VNSequenceRequestHandler
        imageRequestHandler = VNImageRequestHandler(
            ciImage: referenceCIImage
        )
        
        do {
            try imageRequestHandler?.perform([request])
        }
        catch {
            print("Cannot process image request: \(error.localizedDescription)")
        }
        
        guard let results = request.results else {
            return
        }
        
        print("Image processing results")
        for result in results {
            print(result, result.warpTransform)
        }
        
        guard let result = results.first else {
            return
        }
        
        let warpedCIImage = floatingCIImage.perspectiveTransformed(
            by: result.warpTransform
        )

        let backgroundCIImage = referenceCIImage.cropped(
            to: warpedCIImage.extent
        )
        
        let compositeFilter = CIFilter.additionCompositing()
        compositeFilter.backgroundImage = warpedCIImage
        compositeFilter.inputImage = referenceCIImage
        let compositeCIImage = compositeFilter.outputImage!

        print("source", referenceCIImage.extent)
        print("target", floatingCIImage.extent)
        print("warped", warpedCIImage.extent)
        print("final", compositeCIImage.extent)

//        let finalCGImage = ciContext.createCGImage(referenceCIImage, from: referenceCIImage.extent)
//        let finalCGImage = ciContext.createCGImage(floatingCIImage, from: floatingCIImage.extent)
//        let finalCGImage = ciContext.createCGImage(warpedCIImage, from: warpedCIImage.extent)
        let backgroundCGImage = ciContext.createCGImage(backgroundCIImage, from: backgroundCIImage.extent)!
        let compositeCGImage = ciContext.createCGImage(compositeCIImage, from: compositeCIImage.extent)!

//        backgroundImageView.image = UIImage(cgImage: backgroundCGImage)
        previewImageView.image = UIImage(cgImage: compositeCGImage)
    }
}

