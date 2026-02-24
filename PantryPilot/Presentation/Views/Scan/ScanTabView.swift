import SwiftUI
import SwiftData

struct ScanTabView: View {
    @State private var viewModel: ScanViewModel
    @StateObject private var cameraService = CameraService()
    @Environment(\.modelContext) private var modelContext
    @State private var showIgnoreToast = false
    @State private var lastIgnoredItem: ScanViewModel.EditableLineItem?
    let isAuthenticated: Bool
    let isGoogleAccount: Bool
    let profileImageURL: String?
    let onOpenAccount: () -> Void

    init(
        receiptRepository: ReceiptRepositoryProtocol,
        normalizationService: NormalizationService,
        expiryService: ExpiryEstimationService,
        store: InventoryStore,
        useMockAPI: Bool,
        notificationManager: NotificationManager,
        ocrService: ReceiptOCRService,
        isAuthenticated: Bool = false,
        isGoogleAccount: Bool = false,
        profileImageURL: String? = nil,
        onOpenAccount: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: ScanViewModel(
            receiptRepository: receiptRepository,
            normalizationService: normalizationService,
            expiryService: expiryService,
            store: store,
            useMockAPI: useMockAPI,
            notificationManager: notificationManager,
            ocrService: ocrService
        ))
        self.isAuthenticated = isAuthenticated
        self.isGoogleAccount = isGoogleAccount
        self.profileImageURL = profileImageURL
        self.onOpenAccount = onOpenAccount
    }

    private var currentStep: Int {
        switch viewModel.state {
        case .idle: return 0
        case .capturing, .previewing: return 1
        case .processing(.ocr): return 2
        case .processing(.parsing), .confirming: return 3
        case .completed: return 4
        case .error: return 0
        }
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    idleView
                case .capturing:
                    cameraView
                case .previewing(let image):
                    previewView(image: image)
                case .processing:
                    processingView
                case .confirming:
                    confirmView
                case .completed:
                    completedView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Scan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileToolbarButton(
                        isAuthenticated: isAuthenticated,
                        isGoogleAccount: isGoogleAccount,
                        profileImageURL: profileImageURL,
                        action: onOpenAccount
                    )
                }
            }
            .sheet(item: $viewModel.editingItem) { item in
                EditLineItemSheet(item: item) { edited in
                    viewModel.saveEdit(edited)
                }
            }
        }
        .appToast(isPresented: $showIgnoreToast, message: "Ignoriert", icon: "eye.slash") {
            if let item = lastIgnoredItem {
                withAnimation(.spring(response: 0.35)) {
                    viewModel.restoreItem(item)
                }
                lastIgnoredItem = nil
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        AppBackgroundView {
            ScrollView {
                VStack(spacing: AppSpacing.xxl) {
                    Spacer(minLength: AppSpacing.xxl)

                    AppIconBadge(icon: "doc.text.viewfinder", color: AppColors.primary, size: 80)

                    VStack(spacing: AppSpacing.s) {
                        Text("Kassenzettel scannen")
                            .font(AppTypography.headline1)
                        Text("Fotografiere deinen Kassenzettel, um Artikel automatisch zu erfassen.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    }

                    Button {
                        Haptics.medium()
                        viewModel.startCapture()
                    } label: {
                        Label("Scan starten", systemImage: "camera.fill")
                    }
                    .buttonStyle(AppPrimaryButtonStyle(fullWidth: true))
                    .padding(.horizontal, AppSpacing.xxl)

                    tipsSection
                        .padding(.top, AppSpacing.s)

                    Spacer(minLength: AppSpacing.xxl)
                }
                .padding(.horizontal, AppSpacing.l)
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Tipps für bessere Ergebnisse", icon: "lightbulb.fill", iconColor: AppColors.warning)

            VStack(spacing: AppSpacing.s) {
                tipCard(icon: "rectangle.portrait", text: "Kassenzettel glatt hinlegen")
                tipCard(icon: "sun.max.fill", text: "Gute Beleuchtung verwenden")
                tipCard(icon: "viewfinder", text: "Gesamten Zettel erfassen")
            }
        }
    }

    private func tipCard(icon: String, text: String) -> some View {
        AppCard(padding: AppSpacing.m, elevation: .none) {
            HStack(spacing: AppSpacing.m) {
                AppIconBadge(icon: icon, color: AppColors.info, size: 32)
                Text(text)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: AppSpacing.xs) {
            stepDot(1, label: "Foto")
            stepLine(completed: currentStep > 1)
            stepDot(2, label: "OCR")
            stepLine(completed: currentStep > 2)
            stepDot(3, label: "Ergebnis")
        }
        .padding(.vertical, AppSpacing.s)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
    }

    private func stepDot(_ step: Int, label: String) -> some View {
        let isCurrent = step == currentStep
        let isCompleted = step < currentStep
        let isFuture = step > currentStep

        return VStack(spacing: 4) {
            Circle()
                .fill(isFuture ? Color.clear : AppColors.primary.opacity(isCompleted ? 0.45 : 1))
                .overlay {
                    if isFuture {
                        Circle().strokeBorder(AppColors.textTertiary.opacity(0.3), lineWidth: 1.5)
                    }
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
            Text(label)
                .font(AppTypography.caption2)
                .fontWeight(isCurrent ? .semibold : .regular)
                .foregroundStyle(isFuture ? AppColors.textTertiary : AppColors.primary.opacity(isCompleted ? 0.6 : 1))
        }
    }

    private func stepLine(completed: Bool) -> some View {
        Rectangle()
            .fill(completed ? AppColors.primary.opacity(0.35) : AppColors.textTertiary.opacity(0.15))
            .frame(height: completed ? 1.5 : 1)
            .frame(maxWidth: 40)
            .padding(.bottom, 14)
    }

    // MARK: - Camera

    private var cameraView: some View {
        ZStack {
            CameraPreviewView(session: cameraService.session)
                .ignoresSafeArea()
            VStack {
                stepIndicator
                    .padding(.top, AppSpacing.s)
                Spacer()
                HStack(spacing: 40) {
                    Button("Abbrechen") { viewModel.reset() }
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.white)
                    Button {
                        Haptics.medium()
                        cameraService.capturePhoto()
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 70, height: 70)
                            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 4).frame(width: 80, height: 80))
                    }
                    Spacer().frame(width: 80)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            cameraService.checkPermission()
            cameraService.startSession()
        }
        .onDisappear { cameraService.stopSession() }
        .onChange(of: cameraService.capturedImage) { _, newImage in
            if let img = newImage { viewModel.onPhotoCaptured(img) }
        }
    }

    // MARK: - Preview

    private func previewView(image: UIImage) -> some View {
        AppBackgroundView {
            VStack(spacing: AppSpacing.l) {
                stepIndicator

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
                    .shadow(color: AppColors.cardShadow, radius: AppSpacing.cardShadowRadius, y: AppSpacing.cardShadowY)
                    .padding(.horizontal, AppSpacing.l)

                HStack(spacing: AppSpacing.l) {
                    Button("Erneut aufnehmen") { viewModel.reset() }
                        .buttonStyle(AppSecondaryButtonStyle())
                    Button("Analysieren") {
                        Haptics.light()
                        Task { await viewModel.processImage(image) }
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                }
                .padding(.horizontal, AppSpacing.l)
            }
            .padding(.vertical, AppSpacing.l)
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        AppBackgroundView {
            VStack(spacing: AppSpacing.xl) {
                stepIndicator
                Spacer()

                VStack(spacing: AppSpacing.l) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppColors.primary)

                    VStack(spacing: AppSpacing.xs) {
                        Text(viewModel.processingStatus)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)

                        if case .processing(let step) = viewModel.state {
                            Text(step == .ocr ? "Schritt 1/2: Texterkennung" : "Schritt 2/2: KI-Analyse")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }

                LoadingSkeletonView(lineCount: 4)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()
            }
        }
    }

    // MARK: - Confirm

    private var confirmView: some View {
        AppBackgroundView {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.bottom, AppSpacing.s)

                if !viewModel.parsedMerchant.isEmpty {
                    AppCard(padding: AppSpacing.m) {
                        HStack {
                            AppIconBadge(icon: "storefront", color: AppColors.primary, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.parsedMerchant)
                                    .font(AppTypography.bodyMedium)
                                Text(viewModel.parsedDate)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                            Menu {
                                ForEach(StorageLocation.allCases) { loc in
                                    Button("Alle → \(loc.displayName)") {
                                        viewModel.setAllLocation(loc)
                                    }
                                }
                            } label: {
                                Label("Lagerort", systemImage: "tray.2")
                                    .font(AppTypography.caption)
                                    .padding(.horizontal, AppSpacing.s)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.bottom, AppSpacing.m)
                }

                ScrollView {
                    LazyVStack(spacing: AppSpacing.s) {
                        AppSectionHeader(
                            title: "Artikel (\(viewModel.activeItems.count))",
                            icon: "cart.fill"
                        )
                        .padding(.horizontal, AppSpacing.l)

                        ForEach(viewModel.activeItems) { item in
                            confirmRow(item: item)
                                .padding(.horizontal, AppSpacing.l)
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }

                        if !viewModel.ignoredItems.isEmpty {
                            AppSectionHeader(title: "Ignoriert (\(viewModel.ignoredItems.count))", icon: "eye.slash")
                                .padding(.horizontal, AppSpacing.l)
                                .padding(.top, AppSpacing.m)

                            ForEach(viewModel.ignoredItems) { item in
                                ignoredRow(item: item)
                                    .padding(.horizontal, AppSpacing.l)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, AppSpacing.s)
                }

                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: AppSpacing.m) {
                        Button {
                            Haptics.warning()
                            viewModel.reset()
                        } label: {
                            Label("Verwerfen", systemImage: "xmark")
                        }
                        .buttonStyle(AppSecondaryButtonStyle())

                        Button {
                            Haptics.success()
                            Task { await viewModel.addToInventory(context: modelContext) }
                        } label: {
                            Label("\(viewModel.activeItems.count) hinzufügen", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(AppPrimaryButtonStyle(fullWidth: true))
                        .disabled(viewModel.activeItems.isEmpty)
                    }
                    .padding(AppSpacing.l)
                }
                .background(.ultraThinMaterial)
            }
        }
    }

    private func confirmRow(item: ScanViewModel.EditableLineItem) -> some View {
        Button {
            Haptics.selection()
            viewModel.editingItem = item
        } label: {
            AppCard(padding: AppSpacing.m, elevation: .none) {
                HStack(spacing: AppSpacing.m) {
                    AppIconBadge(
                        icon: AppColors.categoryIcon(for: item.category),
                        color: AppColors.categoryColor(for: item.category),
                        size: 36
                    )

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(DisplayNameFormatter.format(item.canonicalName))
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary)
                        HStack(spacing: AppSpacing.s) {
                            AppPillBadge(text: item.category.displayName, color: AppColors.categoryColor(for: item.category), style: .subtle)
                            Text(item.location.shortName)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            if let score = item.dbScore, score > 0.5 {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.success)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let price = item.price {
                            Text(String(format: "%.2f", price * item.quantity))
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        Text("\(item.quantity.formatted()) \(item.unit)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                lastIgnoredItem = item
                withAnimation(.spring(response: 0.35)) {
                    viewModel.ignoreItem(item)
                }
                withAnimation { showIgnoreToast = true }
            } label: {
                Label("Ignorieren", systemImage: "eye.slash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                lastIgnoredItem = item
                withAnimation(.spring(response: 0.35)) {
                    viewModel.ignoreItem(item)
                }
                withAnimation { showIgnoreToast = true }
            } label: {
                Label("Ignorieren", systemImage: "eye.slash")
            }
            .tint(AppColors.textSecondary)
        }
    }

    private func ignoredRow(item: ScanViewModel.EditableLineItem) -> some View {
        AppCard(padding: AppSpacing.m, elevation: .none) {
            HStack {
                Text(item.rawText)
                    .font(AppTypography.callout)
                    .strikethrough()
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.35)) {
                        viewModel.restoreItem(item)
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: AppSpacing.minTapTarget, height: AppSpacing.minTapTarget)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        AppBackgroundView {
            VStack(spacing: AppSpacing.xxl) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppColors.success)
                    .symbolEffect(.bounce, value: true)

                VStack(spacing: AppSpacing.s) {
                    Text("Artikel hinzugefügt!")
                        .font(AppTypography.headline1)
                    Text("Die Artikel wurden erfolgreich zum Inventar hinzugefügt.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }

                Button {
                    Haptics.light()
                    viewModel.reset()
                } label: {
                    Label("Weiteren Kassenzettel scannen", systemImage: "camera.fill")
                }
                .buttonStyle(AppSecondaryButtonStyle())

                Spacer()
            }
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        AppBackgroundView {
            AppEmptyState(
                icon: "exclamationmark.triangle.fill",
                title: "Fehler",
                subtitle: message,
                ctaLabel: "Erneut versuchen"
            ) {
                viewModel.reset()
            }
        }
    }
}

// MARK: - Edit Sheet

struct EditLineItemSheet: View {
    @State var item: ScanViewModel.EditableLineItem
    let onSave: (ScanViewModel.EditableLineItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Originaltext") {
                    Text(item.rawText)
                        .foregroundStyle(AppColors.textSecondary)
                        .font(AppTypography.caption)
                }
                Section("Artikel bearbeiten") {
                    TextField("Name", text: $item.canonicalName)
                    HStack {
                        TextField("Menge", value: $item.quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Picker("Einheit", selection: $item.unit) {
                            ForEach(["Stk", "kg", "g", "L", "ml"], id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                    }
                    Picker("Kategorie", selection: $item.category) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    Picker("Lagerort", selection: $item.location) {
                        ForEach(StorageLocation.allCases) { loc in
                            Text(loc.displayName).tag(loc)
                        }
                    }
                }
            }
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Haptics.success()
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(AppSpacing.cardRadiusLarge)
    }
}
