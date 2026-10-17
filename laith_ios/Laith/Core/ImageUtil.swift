import UIKit

/// Les images sont réduites puis stockées en Base64 dans Firestore (comme sur Android, sans Firebase Storage).
enum ImageUtil {
    private static let cache = NSCache<NSString, UIImage>()

    static func encode(_ src: UIImage, maxSide: CGFloat = 800) -> String? {
        let ratio = maxSide / max(src.size.width, src.size.height)
        var img = src
        if ratio < 1 {
            let size = CGSize(width: max(1, src.size.width * ratio), height: max(1, src.size.height * ratio))
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
            img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in src.draw(in: CGRect(origin: .zero, size: size)) }
        }
        var quality: CGFloat = 0.78
        var text = ""
        repeat {
            guard let data = img.jpegData(compressionQuality: quality) else { return nil }
            text = data.base64EncodedString()
            quality -= 0.12
        } while text.count > 600_000 && quality > 0.2
        return text
    }

    static func decode(_ b64: String?) -> UIImage? {
        guard var s = b64, !s.isEmpty else { return nil }
        if let comma = s.range(of: "base64,") { s = String(s[comma.upperBound...]) }
        if let c = cache.object(forKey: s as NSString) { return c }
        guard let data = Data(base64Encoded: s, options: .ignoreUnknownCharacters), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: s as NSString)
        return img
    }
}
