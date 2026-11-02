import AppKit
import XCTest
@testable import NailGuard

final class NailGuardTests: XCTestCase {
    func testBuzzerIsPlayableOneSecondSound() throws {
        let sound = try XCTUnwrap(NSSound(data: Buzzer.wav()))
        XCTAssertEqual(sound.duration, 1, accuracy: 0.01)
    }

    func testPenaltyNeedsTwoTouchingMouthAnswersInARow() {
        var strikes = Strikes()
        XCTAssertFalse(strikes.record("touching_mouth"))
        XCTAssertFalse(strikes.record("no_contact"))
        XCTAssertFalse(strikes.record("touching_mouth"))
        XCTAssertTrue(strikes.record("touching_mouth"))
        XCTAssertTrue(strikes.record("touching_mouth"))
        XCTAssertFalse(strikes.record("touching_face"))

        XCTAssertFalse(strikes.record("touching_mouth"))
        strikes.reset()
        XCTAssertFalse(strikes.record("touching_mouth"))
    }

    func testAppleVisionLabelFollowsHandDistanceFromMouth() {
        let face = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.35)
        let mouth = CGPoint(x: 0.5, y: 0.5)
        let label = { (points: [CGPoint]) in AppleVision.label(handPoints: points, mouth: mouth, face: face, aspect: 16.0 / 9) }

        XCTAssertEqual(label([CGPoint(x: 0.51, y: 0.5)]), "touching_mouth")
        XCTAssertEqual(label([CGPoint(x: 0.42, y: 0.72), CGPoint(x: 0.9, y: 0.9)]), "touching_face")
        XCTAssertEqual(label([CGPoint(x: 0.9, y: 0.9)]), "no_contact")
        XCTAssertEqual(label([]), "no_contact")
        // 0.05 of the width is 0.25 face widths, but 0.05 of the height is only 0.14 at 16:9.
        XCTAssertEqual(label([CGPoint(x: 0.5, y: 0.45)]), "touching_mouth")
        XCTAssertEqual(label([CGPoint(x: 0.45, y: 0.5)]), "touching_face")
    }
}
