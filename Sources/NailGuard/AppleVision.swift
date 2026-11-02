import Foundation
import Vision

enum AppleVision {
    /// In face widths. Touching frames measured 0.04-0.15 and `no_chin` 0.26, on only 7 posed frames.
    static let mouthThreshold = 0.2
    static let handConfidence: Float = 0.3

    static let labels = ["touching_mouth", "touching_face", "no_contact"]

    /// Returns the label from one frame's hand and lip positions.
    static func classify(_ handler: VNImageRequestHandler, width: Int, height: Int) throws -> String {
        let hands = VNDetectHumanHandPoseRequest()
        hands.maximumHandCount = 2
        try handler.perform([hands])
        // Without a hand the label is always no_contact, and the face detector costs about as much again.
        guard hands.results?.isEmpty == false else { return "no_contact" }
        let faces = VNDetectFaceLandmarksRequest()
        try handler.perform([faces])

        // shortcut: no face counts as no contact, so a hand fully hiding the face is missed; revisit if live tests show it.
        guard let face = faces.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else {
            return "no_contact"
        }
        let handPoints = try (hands.results ?? []).flatMap { hand in
            try hand.recognizedPoints(.all).values.filter { $0.confidence > handConfidence }.map(\.location)
        }
        let box = face.boundingBox
        let lips = (face.landmarks?.outerLips?.normalizedPoints ?? []).map {
            CGPoint(x: box.minX + $0.x * box.width, y: box.minY + $0.y * box.height)
        }
        let mouth = lips.isEmpty
            ? CGPoint(x: box.midX, y: box.minY + box.height * 0.25)
            : CGPoint(x: lips.map(\.x).reduce(0, +) / CGFloat(lips.count), y: lips.map(\.y).reduce(0, +) / CGFloat(lips.count))
        return label(handPoints: handPoints, mouth: mouth, face: box, aspect: Double(width) / Double(height))
    }

    /// All points are normalized to the image; `aspect` is width / height, needed because x and y scale differently.
    static func label(handPoints: [CGPoint], mouth: CGPoint, face: CGRect, aspect: Double) -> String {
        let distance = handPoints.map { point in
            hypot((point.x - mouth.x) * aspect, point.y - mouth.y) / (face.width * aspect)
        }.min()
        if let distance, distance < mouthThreshold { return "touching_mouth" }
        let nearFace = face.insetBy(dx: -face.width * 0.1, dy: -face.height * 0.1)
        return handPoints.contains(where: nearFace.contains) ? "touching_face" : "no_contact"
    }
}
