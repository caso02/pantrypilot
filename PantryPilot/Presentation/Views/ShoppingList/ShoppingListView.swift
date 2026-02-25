import SwiftUI

struct ShoppingListView: View {
    @State private var viewModel: ShoppingListViewModel
    @State private var showCompleted = false
    @State private var showAddedToast = false
    let isAuthenticated: Bool
    let isGoogleAccount: Bool
    let profileImageURL: String?
    let onOpenAccount: () -> Void

    init(
        store: InventoryStore,
        lowStockService: LowStockSuggestionService,
        isAuthenticated: Bool = false,
        isGoogleAccount: Bool = false,
        profileImageURL: String? = nil,
        onOpenAccount: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: ShoppingListViewModel(
            store: store,
            lowStockService: lowStockService
        ))
        self.isAuthenticated = isAuthenticated
        self.isGoogleAccount = isGoogleAccount
        self.profileImageURL = profileImageURL
        self.onOpenAccount = onOpenAccount
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            AppBackgroundView {
                if viewModel.shoppingList.isEmpty && viewModel.topSuggestions.isEmpty {
                    AppEmptyState(
                        icon: "cart",
                        title: "Einkaufsliste leer",
                        subtitle: "Füge Artikel hinzu oder nutze Vorschläge aus deinem Inventar.",
                        ctaLabel: "Artikel hinzufügen"
                    ) {
                        viewModel.showAddSheet = true
                    }
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.l) {
                            headerSubtitleLine

                            if !viewModel.topSuggestions.isEmpty {
                                suggestionsSection
                            }

                            if !viewModel.pendingItems.isEmpty {
                                groupedPendingSection
                            } else if !viewModel.topSuggestions.isEmpty {
                                listEmptyHint
                            }

                            if !viewModel.completedItems.isEmpty {
                                completedSection
                            }
                        }
                        .padding(.horizontal, AppSpacing.l)
                        .padding(.top, AppSpacing.m)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationTitle("Einkaufsliste")
            .safeAreaInset(edge: .bottom) {
                quickAddBar
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.bottom, 6)
            }
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
            .sheet(isPresented: $viewModel.showAddSheet) {
                addItemSheet
            }
            .sheet(isPresented: $viewModel.showAllSuggestions) {
                allSuggestionsSheet
            }
        }
        .appToast(isPresented: $showAddedToast, message: "Zur Liste hinzugefügt")
    }

    // MARK: - Quick Add Bar

    @State private var quickAddText = ""

    private var headerSubtitleLine: some View {
        HStack(spacing: AppSpacing.m) {
            Text("\(viewModel.pendingItems.count) Artikel offen")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 0) {
            TextField("Artikel schnell hinzufügen...", text: $quickAddText)
                .font(.system(size: 15))
                .padding(.leading, 16)
                .onSubmit { submitQuickAdd() }

            Button {
                submitQuickAdd()
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(
                        quickAddText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppColors.primary.opacity(0.45)
                            : AppColors.primary
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(quickAddText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(6)
        }
        .background(
            Capsule()
                .fill(AppColors.surface)
                .overlay(
                    Capsule()
                        .stroke(AppColors.primary.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    private func submitQuickAdd() {
        let text = quickAddText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        viewModel.newItemName = text
        viewModel.addItem()
        quickAddText = ""
        withAnimation { showAddedToast = true }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Text("Häufig gekauft")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if viewModel.hasMoreSuggestions {
                    Button("Alle") { viewModel.showAllSuggestions = true }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.topSuggestions) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func suggestionChip(_ suggestion: LowStockSuggestionService.Suggestion) -> some View {
        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.35)) {
                viewModel.addSuggestion(suggestion)
            }
            withAnimation { showAddedToast = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.primary)
                Text(DisplayNameFormatter.format(suggestion.name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.surface)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(SuggestionChipButtonStyle())
    }

    // MARK: - List Empty Hint

    private var listEmptyHint: some View {
        HStack(spacing: AppSpacing.m) {
            Image(systemName: "cart")
                .font(.title3)
                .foregroundStyle(AppColors.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Noch keine Artikel")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Text("Nutze die Vorschläge oben oder tippe +")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(AppSpacing.l)
        .background {
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(AppColors.textTertiary.opacity(0.04))
                .strokeBorder(AppColors.cardStroke, lineWidth: 0.5)
        }
    }

    // MARK: - Pending Items

    private var groupedPendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            ForEach(groupedPendingItems, id: \.category) { group in
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack(spacing: 8) {
                        Image(systemName: group.category.icon)
                            .foregroundStyle(AppColors.primary)
                        Text(group.category.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    AppCard(padding: 0, elevation: .none) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                shoppingRow(item: item)
                                    .padding(.horizontal, AppSpacing.m)
                                    .padding(.vertical, AppSpacing.s)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.toggleItem(item)
                                        }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Haptics.warning()
                                            withAnimation(.spring(response: 0.35)) {
                                                viewModel.removeItem(item)
                                            }
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }

                                if index < group.items.count - 1 {
                                    Divider()
                                        .padding(.horizontal, AppSpacing.m)
                                        .opacity(0.5)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Completed Items

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Button {
                Haptics.selection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showCompleted.toggle()
                }
            } label: {
                AppCard(padding: AppSpacing.m, elevation: .none) {
                    HStack(spacing: AppSpacing.s) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(AppColors.success.opacity(0.5))
                        Text("Erledigt")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textSecondary)
                        AppPillBadge(
                            text: "\(viewModel.completedItems.count)",
                            color: AppColors.textSecondary,
                            style: .subtle
                        )
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.textTertiary)
                            .rotationEffect(.degrees(showCompleted ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)

            if showCompleted {
                AppCard(padding: 0, elevation: .none) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.completedItems.enumerated()), id: \.element.id) { index, item in
                            shoppingRow(item: item)
                                .padding(.horizontal, AppSpacing.m)
                                .padding(.vertical, AppSpacing.s)
                                .opacity(0.5)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Haptics.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        viewModel.toggleItem(item)
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Haptics.warning()
                                        withAnimation { viewModel.removeItem(item) }
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }

                            if index < viewModel.completedItems.count - 1 {
                                Divider()
                                    .padding(.horizontal, AppSpacing.m)
                                    .opacity(0.3)
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Shopping Row

    private func shoppingRow(item: ShoppingListItem) -> some View {
        HStack(spacing: AppSpacing.m) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isCompleted ? AppColors.primary : Color(.tertiaryLabel))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(DisplayNameFormatter.format(item.name))
                    .font(.system(size: 15, weight: .medium))
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? AppColors.textTertiary : AppColors.textPrimary)
                if let qty = item.targetQuantity, let unit = item.unit {
                    Text("\(qty.formatted()) \(unit)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()

            if item.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.primary.opacity(0.3))
            }
        }
    }

    private var groupedPendingItems: [(category: ShoppingListCategory, items: [ShoppingListItem])] {
        let grouped = Dictionary(grouping: viewModel.pendingItems) { item in
            ShoppingListCategory.resolve(for: item.name)
        }
        return ShoppingListCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    // MARK: - Add Item Sheet

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                TextField("Artikelname", text: $viewModel.newItemName)
                TextField("Menge", text: $viewModel.newItemQuantity)
                    .keyboardType(.decimalPad)
                Picker("Einheit", selection: $viewModel.newItemUnit) {
                    ForEach(["Stk", "kg", "g", "L", "ml"], id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
            }
            .navigationTitle("Artikel hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { viewModel.showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        Haptics.success()
                        viewModel.addItem()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.newItemName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(AppSpacing.cardRadiusLarge)
    }

    // MARK: - All Suggestions Sheet

    private var allSuggestionsSheet: some View {
        NavigationStack {
            AppBackgroundView {
                ScrollView {
                    VStack(spacing: AppSpacing.s) {
                        ForEach(viewModel.fullSuggestions) { suggestion in
                            AppCard(padding: AppSpacing.m, elevation: .none) {
                                HStack(spacing: AppSpacing.m) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(DisplayNameFormatter.format(suggestion.name))
                                            .font(AppTypography.bodyMedium)
                                        Text(suggestion.reason)
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.textTertiary)
                                    }
                                    Spacer()
                                    Button {
                                        Haptics.light()
                                        viewModel.addSuggestion(suggestion)
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppColors.primary)
                                            .frame(width: 30, height: 30)
                                            .background(AppColors.primary.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.s)
                }
            }
            .navigationTitle("Alle Vorschläge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { viewModel.showAllSuggestions = false }
                }
            }
        }
    }
}

private enum ShoppingListCategory: CaseIterable {
    case produce
    case dairy
    case pantry
    case other

    var title: String {
        switch self {
        case .produce: return "Gemüse & Obst"
        case .dairy: return "Milch & Eier"
        case .pantry: return "Vorratskammer"
        case .other: return "Sonstiges"
        }
    }

    var icon: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .pantry: return "cabinet.fill"
        case .other: return "basket.fill"
        }
    }

    static func resolve(for name: String) -> ShoppingListCategory {
        let n = name.lowercased()
        if n.contains("milk") || n.contains("milch") || n.contains("joghurt") || n.contains("yogurt") || n.contains("egg") || n.contains("ei") || n.contains("butter") || n.contains("cheese") || n.contains("käse") {
            return .dairy
        }
        if n.contains("apple") || n.contains("apfel") || n.contains("tomato") || n.contains("tomate") || n.contains("spinach") || n.contains("salad") || n.contains("salat") || n.contains("pepper") || n.contains("karotte") || n.contains("gemüse") {
            return .produce
        }
        if n.contains("pasta") || n.contains("rice") || n.contains("reis") || n.contains("flour") || n.contains("mehl") || n.contains("bread") || n.contains("brot") || n.contains("salt") || n.contains("oil") || n.contains("sauce") {
            return .pantry
        }
        return .other
    }
}

private struct SuggestionChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
