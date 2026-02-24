import Foundation
import Vision
import UIKit

final class ReceiptOCRService: Sendable {

    struct OCRResult: Sendable {
        let lines: [String]
        let fullText: String
    }

    struct RecognizedBlock: Sendable {
        let text: String
        let midY: CGFloat
        let minX: CGFloat
        let height: CGFloat
    }

    func recognizeText(in image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        // Preserve UIImage orientation so Vision reads the image upright.
        // cgImage strips orientation metadata, so we pass it explicitly.
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(lines: [], fullText: ""))
                    return
                }

                var blocks: [RecognizedBlock] = []
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let box = obs.boundingBox
                    blocks.append(RecognizedBlock(
                        text: candidate.string,
                        midY: box.midY,
                        minX: box.minX,
                        height: box.height
                    ))
                }

#if DEBUG
                AppLogger.ocr.debug("OCR raw observations (\(blocks.count)):")
                for (i, b) in blocks.sorted(by: { $0.midY > $1.midY }).enumerated() {
                    AppLogger.ocr.debug("  [\(i)] y=\(String(format: "%.3f", b.midY)) x=\(String(format: "%.3f", b.minX)): \"\(b.text)\"")
                }
#endif

                let rows = Self.groupIntoRows(blocks)
#if DEBUG
                AppLogger.ocr.debug("OCR grouped rows (\(rows.count)):")
                for (i, row) in rows.enumerated() {
                    AppLogger.ocr.debug("  Row \(i + 1): \"\(row)\"")
                }
#endif
                let fullText = rows.joined(separator: "\n")
                continuation.resume(returning: OCRResult(lines: rows, fullText: fullText))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "de-CH", "en-US"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    private static func groupIntoRows(_ blocks: [RecognizedBlock]) -> [String] {
        guard !blocks.isEmpty else { return [] }

        let lineHeight = estimateLineHeight(blocks)
        let threshold = lineHeight * 0.5

        let sorted = blocks.sorted { $0.midY > $1.midY }

        var rows: [[RecognizedBlock]] = [[sorted[0]]]
        var rowCenterY: [CGFloat] = [sorted[0].midY]

        for i in 1..<sorted.count {
            let block = sorted[i]

            if let bestRow = closestRow(for: block.midY, centers: rowCenterY, threshold: threshold) {
                rows[bestRow].append(block)
                let n = CGFloat(rows[bestRow].count)
                rowCenterY[bestRow] = (rowCenterY[bestRow] * (n - 1) + block.midY) / n
            } else {
                rows.append([block])
                rowCenterY.append(block.midY)
            }
        }

        let sortedRows = zip(rows, rowCenterY)
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        return sortedRows.map { row in
            row.sorted { $0.minX < $1.minX }
                .map(\.text)
                .joined(separator: " ")
        }
    }

    private static func closestRow(for y: CGFloat, centers: [CGFloat], threshold: CGFloat) -> Int? {
        var bestIdx: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for (i, center) in centers.enumerated() {
            let dist = abs(center - y)
            if dist < threshold && dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }

        return bestIdx
    }

    private static func estimateLineHeight(_ blocks: [RecognizedBlock]) -> CGFloat {
        let heights = blocks.map(\.height).sorted()
        guard !heights.isEmpty else { return 0.015 }
        let median = heights[heights.count / 2]
        return max(median, 0.005)
    }

    func extractReceiptLines(from ocrResult: OCRResult) -> [String] {
        let trimmed = ocrResult.lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [String] = []

        for line in trimmed {
            let lower = line.lowercased()
            let stripped = line.replacingOccurrences(of: " ", with: "")

            guard line.count >= 2 else { continue }

            if stripped.count > 12 && stripped.filter(\.isNumber).count > stripped.count * 3 / 4 {
                continue
            }

            if line.allSatisfy({ "=-*_.#/ ".contains($0) }) {
                continue
            }

            let skipPrefixes = [
                "filiale", "kasse", "datum", "zeit",
                "visa", "mastercard", "twint",
                "danke", "vielen dank", "www.", "http",
                "quittung", "öffnungszeiten",
                "erhaltene punkte", "che-",
            ]
            if skipPrefixes.contains(where: { lower.hasPrefix($0) }) {
                continue
            }

            let skipContains = [
                "/x", "posts", "tab", "fenster", "profil",
                "hilfe", "bachelorarbeit", "schreibe",
            ]
            if skipContains.contains(where: { lower.contains($0) }) {
                continue
            }

            result.append(line)
        }

        return result
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .down:          self = .down
        case .left:          self = .left
        case .right:         self = .right
        case .upMirrored:    self = .upMirrored
        case .downMirrored:  self = .downMirrored
        case .leftMirrored:  self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Das Bild konnte nicht verarbeitet werden."
        case .recognitionFailed(let error):
            return "Texterkennung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
