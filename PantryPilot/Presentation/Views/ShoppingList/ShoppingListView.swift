import SwiftUI

struct ShoppingListView: View {
    @State private var viewModel: ShoppingListViewModel
    @State private var showCompleted = false
    @State private var showAddedToast = false

    init(store: InventoryStore, lowStockService: LowStockSuggestionService) {
        _viewModel = State(initialValue: ShoppingListViewModel(
            store: store,
            lowStockService: lowStockService
        ))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            AppBackgroundView {
                ZStack(alignment: .bottomTrailing) {
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
                                if !viewModel.topSuggestions.isEmpty {
                                    suggestionsCard
                                }

                                if !viewModel.pendingItems.isEmpty {
                                    pendingSection
                                } else if !viewModel.topSuggestions.isEmpty {
                                    listEmptyHint
                                }

                                if !viewModel.completedItems.isEmpty {
                                    completedSection
                                }
                            }
                            .padding(.horizontal, AppSpacing.l)
                            .padding(.top, AppSpacing.m)
                            .padding(.bottom, 90)
                        }
                    }

                    AppFloatingActionButton(icon: "plus") {
                        viewModel.showAddSheet = true
                    }
                }
            }
            .navigationTitle("Einkaufsliste")
            .sheet(isPresented: $viewModel.showAddSheet) {
                addItemSheet
            }
            .sheet(isPresented: $viewModel.showAllSuggestions) {
                allSuggestionsSheet
            }
        }
        .appToast(isPresented: $showAddedToast, message: "Zur Liste hinzugefügt")
    }

    // MARK: - Suggestions

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            AppSectionHeader(
                title: "Vorschläge",
                icon: "lightbulb.fill",
                iconColor: AppColors.warning,
                trailing: viewModel.hasMoreSuggestions ? "Alle" : nil,
                trailingAction: { viewModel.showAllSuggestions = true }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.s) {
                    ForEach(viewModel.topSuggestions) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
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
            HStack(spacing: AppSpacing.s) {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(AppColors.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(DisplayNameFormatter.format(suggestion.name))
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(suggestion.reason)
                        .font(AppTypography.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.s)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 0.5)
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

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            AppSectionHeader(title: "Einkaufsliste (\(viewModel.pendingItems.count))", icon: "cart.fill")

            AppCard(padding: 0, elevation: .none) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.pendingItems.enumerated()), id: \.element.id) { index, item in
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
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))

                        if index < viewModel.pendingItems.count - 1 {
                            Divider()
                                .padding(.horizontal, AppSpacing.m)
                                .opacity(0.5)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.xs)
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
                .foregroundStyle(item.isCompleted ? AppColors.success : AppColors.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(DisplayNameFormatter.format(item.name))
                    .font(AppTypography.bodyMedium)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? AppColors.textTertiary : AppColors.textPrimary)
                if let qty = item.targetQuantity, let unit = item.unit {
                    Text("\(qty.formatted()) \(unit)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()
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

private struct SuggestionChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
