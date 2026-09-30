import SwiftUI
import UIKit
import XCTest
@testable import SoftNotes

/// Pixel checks for the fold (run: `scripts/ui-shots.sh SoftNotesTests/FoldingCardTests`).
/// Renders views off-screen with `ImageRenderer` at 3× and diffs them; both
/// renders and an amplified diff are attached (exported to build/shots/ui/).
@MainActor
final class FoldingCardTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_588_460)   // fixed, so the header can't change mid-test
    private var content: NoteCardContent<NoteCardStaticText> {
        NoteCardContent(icon: .defaultIcon, date: date, tag: "Daily", text: "Have a good day")
    }

    /// The two clipped halves at 0° must reproduce the resting card — no seam
    /// on the fold line. At rest the card sits on whole points (FoldStage
    /// rounds its centre), which is the case that must be exact.
    func testFoldingCardAtRestMatchesCard() throws {
        for offset in [CGFloat(0), 0.5] {
            let card = try pixels(of: framed(content, offset: offset))
            let folding = try pixels(of: framed(FoldingCardView(angle: 0, content: content), offset: offset))
            let diff = Diff(card, folding)
            let report = "fold-at-rest offset \(offset): max channel diff \(diff.max), pixels > 2: \(diff.over2), rows \(diff.rows)"
            print(report)
            attach(card, folding, diff, name: "fold-rest-\(offset == 0 ? "grid" : "half")")
            if offset == 0 {
                XCTAssertLessThanOrEqual(diff.max, 2, report)
            }
        }
    }

    /// The stage's hand-off frame: card at the write step's spot and pose
    /// (resting, −3°), header icon
    /// replaced by the travelling 82pt icon scaled to 32pt. Everything outside
    /// the icon must match the plain card.
    func testStageHandOffMatchesCard() throws {
        let screen = CGSize(width: 402, height: 874)
        let size = NoteCardContent<NoteCardStaticText>.size
        let frame = CGRect(x: 83, y: 308, width: size.width, height: size.height)
        let fold = FoldCard(icon: .defaultIcon, date: date, tag: "Daily", text: "Have a good day",
                            sourceFrame: frame, sourcePose: .resting)
        let stage = try pixels(of: FoldStage(card: fold, phase: .idle)
            .frame(width: screen.width, height: screen.height)
            .background(Theme.Palette.canvas))
        let plain = try pixels(of: NoteCardView(pose: .resting, content: content)
            .position(x: frame.midX, y: frame.midY)
            .frame(width: screen.width, height: screen.height)
            .background(Theme.Palette.canvas))
        // The icon may differ (anti-aliasing / glass sampling at 82pt scaled
        // to 32pt — indistinguishable by eye); the rest of the card must not,
        // apart from sub-visible anti-aliasing along the tilted fold line.
        let icon = NoteCardContent<NoteCardStaticText>.headerIconCenter
        let box = CGRect(x: frame.minX + icon.x, y: frame.minY + icon.y, width: 0, height: 0)
            .insetBy(dx: -26, dy: -26)
        let diff = Diff(stage, plain, excluding: box)
        let report = "stage hand-off: icon max diff \(diff.max), elsewhere max \(diff.maxOutside); pixels > 8: \(diff.over8)"
        print(report)
        attach(stage, plain, diff, name: "fold-handoff")
        XCTAssertLessThanOrEqual(diff.maxOutside, 8, report)
    }

    // MARK: - Helpers

    private func framed(_ view: some View, offset: CGFloat) -> some View {
        view
            .padding(EdgeInsets(top: 60 + offset, leading: 60 + offset, bottom: 60, trailing: 60))
            .background(Theme.Palette.canvas)
    }

    private struct Pixels { var width: Int; var height: Int; var bytes: [UInt8] }

    private struct Diff {
        var max = 0, over2 = 0, over8 = 0
        var rows = 0..<0, cols = 0..<0
        /// Max channel difference outside `excluding` (points).
        var maxOutside = 0
        var map: [UInt8]
        init(_ a: Pixels, _ b: Pixels, excluding: CGRect = .null) {
            precondition(a.width == b.width && a.height == b.height, "size mismatch")
            map = [UInt8](repeating: 255, count: a.bytes.count)
            var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
            for i in stride(from: 0, to: a.bytes.count, by: 4) {
                var d = 0
                for c in 0..<3 { d = Swift.max(d, abs(Int(a.bytes[i + c]) - Int(b.bytes[i + c]))) }
                max = Swift.max(max, d)
                let point = CGPoint(x: CGFloat((i / 4) % a.width) / 3, y: CGFloat((i / 4) / a.width) / 3)
                if !excluding.contains(point) { maxOutside = Swift.max(maxOutside, d) }
                if d > 2 {
                    over2 += 1
                    let p = i / 4, x = p % a.width, y = p / a.width
                    minX = Swift.min(minX, x); maxX = Swift.max(maxX, x)
                    minY = Swift.min(minY, y); maxY = Swift.max(maxY, y)
                }
                if d > 8 { over8 += 1 }
                let shade = UInt8(Swift.max(0, 255 - d * 8))
                map[i] = 255; map[i + 1] = shade; map[i + 2] = shade; map[i + 3] = 255
            }
            if maxX >= 0 { rows = (minY / 3)..<(maxY / 3 + 1); cols = (minX / 3)..<(maxX / 3 + 1) }
        }
    }

    private func pixels(of view: some View) throws -> Pixels {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.cgImage, "render failed")
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Pixels(width: width, height: height, bytes: bytes)
    }

    private func attach(_ a: Pixels, _ b: Pixels, _ diff: Diff, name: String) {
        for (suffix, bytes) in [("a", a.bytes), ("b", b.bytes), ("diff", diff.map)] {
            guard let image = Self.image(bytes, width: a.width, height: a.height) else { continue }
            let attachment = XCTAttachment(image: image)
            attachment.name = "\(name)_\(suffix)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private static func image(_ bytes: [UInt8], width: Int, height: Int) -> UIImage? {
        var copy = bytes
        return copy.withUnsafeMutableBytes { buffer -> UIImage? in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let cg = context.makeImage() else { return nil }
            return UIImage(cgImage: cg)
        }
    }
}
