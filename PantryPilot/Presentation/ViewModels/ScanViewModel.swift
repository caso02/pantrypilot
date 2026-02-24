import Foundation
import SwiftUI
import SwiftData
import UIKit

@Observable
@MainActor
final class ScanViewModel {
    enum ScanState: Equatable {
        case idle
        case capturing
        case previewing(UIImage)
        case processing(ProcessingStep)
        case confirming
        case completed
        case error(String)

        static func == (lhs: ScanState, rhs: ScanState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.capturing, .capturing),
                 (.confirming, .confirming), (.completed, .completed):
                return true
            case (.previewing, .previewing):
                return true
            case (.processing(let a), .processing(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    enum ProcessingStep: Equatable {
        case ocr
        case parsing
    }

    struct EditableLineItem: Identifiable {
        let id: UUID
        let rawText: String
        var canonicalName: String
        var quantity: Double
        var unit: String
        var price: Double?
        var category: FoodCategory
        var location: StorageLocation
        var isIgnored: Bool
        var confidence: String
        var dbScore: Double?

        init(from parsed: ParsedAndMatchedLine, normService: NormalizationService) {
            self.id = UUID()
            self.rawText = parsed.rawText
            self.confidence = parsed.llm.confidence ?? "medium"

            let score = parsed.match?.score ?? 0
            let useDBName = score >= 0.5 && parsed.match?.canonicalName != nil
            let productName = useDBName ? parsed.match!.canonicalName : parsed.llm.productName
            self.canonicalName = productName.isEmpty ? parsed.rawText : productName

            let parsedQuantity = parsed.llm.quantity ?? 1
            self.quantity = parsedQuantity > 0 ? parsedQuantity : 1
            self.unit = parsed.llm.unit ?? "Stk"
            self.price = parsed.llm.unitPrice
            self.dbScore = parsed.match?.score

            let llmCategory = parsed.llm.category
            self.category = Self.mapCategory(llmCategory) ?? normService.guessCategory(for: productName)
            self.location = NormalizationService.defaultLocationForCategory[self.category] ?? .pantry
            self.isIgnored = normService.isNonFood(parsed.rawText) || self.confidence == "low"
        }

        init(from parsed: ParsedLineItem, normService: NormalizationService) {
            self.id = parsed.id
            self.rawText = parsed.rawText
            let normalized = normService.normalize(parsed.rawText)
            self.canonicalName = normalized
            let parsedQuantity = parsed.quantity ?? 1
            self.quantity = parsedQuantity > 0 ? parsedQuantity : 1
            self.unit = parsed.unit ?? "Stk"
            self.price = parsed.price
            self.confidence = "medium"
            self.dbScore = nil
            let cat = normService.guessCategory(for: normalized)
            self.category = cat
            self.location = NormalizationService.defaultLocationForCategory[cat] ?? .pantry
            self.isIgnored = normService.isNonFood(parsed.rawText)
        }

        private static func mapCategory(_ llmCategory: String?) -> FoodCategory? {
            guard let cat = llmCategory?.lowercased() else { return nil }
            let mapping: [String: FoodCategory] = [
                "milchprodukte": .dairy, "milch": .dairy,
                "fleisch": .meat, "fisch": .meat, "fleisch & fisch": .meat,
                "gemüse": .produce, "früchte": .produce, "obst & gemüse": .produce, "obst": .produce,
                "brot/backwaren": .bakery, "backwaren": .bakery, "brot": .bakery,
                "tiefkühl": .frozen,
                "konserven": .canned,
                "getränke": .beverages,
                "snacks": .snacks, "süsswaren": .snacks,
                "gewürze & saucen": .condiments, "gewürze": .condiments,
                "getreide & nudeln": .grains, "getreide": .grains,
                "haushalt": .other, "hygiene": .other, "sonstiges": .other,
            ]
            return mapping[cat]
        }
    }

    var state: ScanState = .idle
    var parsedMerchant: String = ""
    var parsedDate: String = ""
    var editingItem: EditableLineItem? = nil
    var ocrLineCount: Int = 0
    var processingStatus: String = ""

    private var allItems: [EditableLineItem] = []

    private let receiptRepository: ReceiptRepositoryProtocol
    private let normalizationService: NormalizationService
    private let expiryService: ExpiryEstimationService
    private let store: InventoryStore
    private let useMockAPI: Bool
    private let notificationManager: NotificationManager
    private let ocrService: ReceiptOCRService

    init(
        receiptRepository: ReceiptRepositoryProtocol,
        normalizationService: NormalizationService,
        expiryService: ExpiryEstimationService,
        store: InventoryStore,
        useMockAPI: Bool,
        notificationManager: NotificationManager,
        ocrService: ReceiptOCRService
    ) {
        self.receiptRepository = receiptRepository
        self.normalizationService = normalizationService
        self.expiryService = expiryService
        self.store = store
        self.useMockAPI = useMockAPI
        self.notificationManager = notificationManager
        self.ocrService = ocrService
    }

    var activeItems: [EditableLineItem] {
        allItems.filter { !$0.isIgnored }
    }

    var ignoredItems: [EditableLineItem] {
        allItems.filter { $0.isIgnored }
    }

    func startCapture() {
        if useMockAPI {
            useMockImage()
        } else {
            state = .capturing
        }
    }

    func useMockImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 500))
        let placeholderImage = renderer.image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 500))
            let text = "MIGROS Kassenbon" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.label
            ]
            text.draw(at: CGPoint(x: 70, y: 20), withAttributes: attrs)
        }
        state = .previewing(placeholderImage)
    }

    func onPhotoCaptured(_ image: UIImage) {
        state = .previewing(image)
    }

    func processImage(_ image: UIImage) async {
        if useMockAPI {
            await processWithMockAPI(image)
        } else {
            await processWithOCRAndBackend(image)
        }
    }

    private func processWithOCRAndBackend(_ image: UIImage) async {
        state = .processing(.ocr)
        processingStatus = "Texterkennung läuft…"

        let ocrResult: ReceiptOCRService.OCRResult
        do {
            ocrResult = try await ocrService.recognizeText(in: image)
        } catch {
            state = .error("OCR fehlgeschlagen: \(error.localizedDescription)")
            return
        }

        let receiptLines = ocrService.extractReceiptLines(from: ocrResult)
        ocrLineCount = receiptLines.count

        if receiptLines.isEmpty {
            state = .error("Kein Text auf dem Kassenzettel erkannt. Bitte erneut fotografieren.")
            return
        }

        state = .processing(.parsing)
        processingStatus = "\(receiptLines.count) Zeilen erkannt. Produkte werden identifiziert…"

        do {
            let response = try await receiptRepository.parseReceiptLines(receiptLines)

            parsedMerchant = Self.detectMerchant(from: receiptLines)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.locale = Locale(identifier: "de_CH")
            parsedDate = formatter.string(from: Date())

            allItems = response.parsed.map { EditableLineItem(from: $0, normService: normalizationService) }
            state = .confirming
        } catch {
            state = .error("Produkterkennung fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func processWithMockAPI(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            state = .error("Bild konnte nicht verarbeitet werden.")
            return
        }
        state = .processing(.parsing)
        processingStatus = "Kassenzettel wird analysiert…"

        do {
            let result = try await receiptRepository.uploadAndParse(imageData: data)
            parsedMerchant = result.merchant
            parsedDate = result.purchaseDate
            allItems = result.lineItems.map { EditableLineItem(from: $0, normService: normalizationService) }
            state = .confirming
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @available(*, deprecated, message: "Use processImage instead")
    func uploadImage(_ image: UIImage) async {
        await processImage(image)
    }

    func ignoreItem(_ item: EditableLineItem) {
        if let idx = allItems.firstIndex(where: { $0.id == item.id }) {
            allItems[idx].isIgnored = true
        }
    }

    func restoreItem(_ item: EditableLineItem) {
        if let idx = allItems.firstIndex(where: { $0.id == item.id }) {
            allItems[idx].isIgnored = false
        }
    }

    func setAllLocation(_ location: StorageLocation) {
        for i in allItems.indices where !allItems[i].isIgnored {
            allItems[i].location = location
        }
    }

    func saveEdit(_ edited: EditableLineItem) {
        if let idx = allItems.firstIndex(where: { $0.id == edited.id }) {
            allItems[idx].canonicalName = edited.canonicalName
            allItems[idx].quantity = edited.quantity
            allItems[idx].unit = edited.unit
            allItems[idx].category = edited.category
            allItems[idx].location = edited.location
        }
        editingItem = nil
    }

    func addToInventory(context: ModelContext) async {
        let items = activeItems
        let inventoryItems = items.map { item -> InventoryItem in
            let expiry = expiryService.estimateExpiry(
                category: item.category,
                location: item.location,
                opened: false,
                from: .now
            )
            return InventoryItem(
                canonicalName: item.canonicalName,
                quantity: item.quantity,
                unit: item.unit,
                location: item.location,
                purchaseDate: .now,
                estimatedExpiryDate: expiry,
                category: item.category
            )
        }

        for item in items {
            let normalized = normalizationService.normalize(item.rawText)
            if item.canonicalName != normalized || normalizationService.guessCategory(for: normalized) != item.category {
                normalizationService.saveUserMapping(
                    rawText: item.rawText,
                    canonicalName: item.canonicalName,
                    category: item.category,
                    context: context
                )
            }
        }

        let receiptLineItems = items.map { item in
            ReceiptLineItem(
                name: item.canonicalName,
                quantity: item.quantity,
                unit: item.unit,
                unitPrice: item.price,
                category: item.category
            )
        }
        let totalAmount = receiptLineItems.reduce(0.0) { sum, item in
            guard let price = item.unitPrice else { return sum }
            return sum + price * item.quantity
        }
        let receipt = Receipt(
            merchant: parsedMerchant.isEmpty ? "Migros" : parsedMerchant,
            date: .now,
            totalAmount: totalAmount > 0 ? totalAmount : nil,
            itemCount: receiptLineItems.count,
            lineItems: receiptLineItems
        )
        let persisted = PersistedReceipt.from(receipt)
        context.insert(persisted)
        do {
            try context.save()
        } catch {
            AppLogger.persistence.error("Failed to persist receipt: \(error.localizedDescription)")
            state = .error("Kassenzettel konnte nicht gespeichert werden. Bitte erneut versuchen.")
            return
        }

        await store.addItems(inventoryItems)
        notificationManager.scheduleExpiryNotifications(for: inventoryItems)
        state = .completed
    }

    func reset() {
        state = .idle
        parsedMerchant = ""
        parsedDate = ""
        editingItem = nil
        allItems = []
        ocrLineCount = 0
        processingStatus = ""
    }

    private static func detectMerchant(from lines: [String]) -> String {
        let joined = lines.joined(separator: " ").lowercased()
        if joined.contains("coop") { return "Coop" }
        if joined.contains("migros") { return "Migros" }
        if joined.contains("aldi") { return "Aldi" }
        if joined.contains("lidl") { return "Lidl" }
        if joined.contains("denner") { return "Denner" }
        if joined.contains("spar") { return "Spar" }
        if joined.contains("volg") { return "Volg" }
        return "Supermarkt"
    }
}
