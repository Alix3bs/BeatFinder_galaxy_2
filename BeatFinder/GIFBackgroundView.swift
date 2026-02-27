import SwiftUI
import UIKit
import ImageIO

struct GIFBackgroundView: UIViewRepresentable {
    let gifName: String // exact filename in Xcode, e.g. "safe_galaxy.gif"

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.isHidden = true

        container.addSubview(imageView)
        container.addSubview(label)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
        ])

        if let (image, _) = UIImage.debugAnimatedGIF(named: gifName) {
            imageView.image = image
            label.isHidden = true
        } else {
            label.text = """
            GIF FAILED:
            \(gifName)

            Fix:
            Make sure this exact file is in:
            Build Phases → Copy Bundle Resources
            """
            label.isHidden = false
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension UIImage {
    static func debugAnimatedGIF(named name: String) -> (UIImage, String)? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else { return nil }
        guard let data = try? Data(contentsOf: url), data.count > 12 else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            duration += frameDuration(source: source, index: i)
        }

        if images.isEmpty { return nil }
        if duration == 0 { duration = Double(count) * 0.1 }

        let animated = UIImage.animatedImage(with: images, duration: duration) ?? images[0]
        return (animated, "OK")
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> Double {
        guard
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else { return 0.1 }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let d = unclamped ?? clamped ?? 0.1
        return d < 0.02 ? 0.1 : d
    }
}
