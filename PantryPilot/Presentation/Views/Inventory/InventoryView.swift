import SwiftUI

struct InventoryView: View {
    @State private var viewModel: InventoryViewModel
    @State private var expandedCategories: Set<String> = []
    @State private var showDeleteToast = false
    @State private var selectedCategoryFilter: FoodCategory? = nil
    @State private var selectedSortOption: InventorySortOption = .newestFirst
    let isAuthenticated: Bool
    let isGoogleAccount: Bool
    let profileImageURL: String?
    let onOpenAccount: () -> Void

    init(
        store: InventoryStore,
        isAuthenticated: Bool = false,
        isGoogleAccount: Bool = false,
        profileImageURL: String? = nil,
        onOpenAccount: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: InventoryViewModel(store: store))
        self.isAuthenticated = isAuthenticated
        self.isGoogleAccount = isGoogleAccount
        self.profileImageURL = profileImageURL
        self.onOpenAccount = onOpenAccount
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            AppBackgroundView {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if viewModel.isLoading {
                            LoadingSkeletonView(lineCount: 6)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, AppSpacing.xl)
                        } else if !viewModel.hasAnyItems {
                            AppEmptyState(
                                icon: "refrigerator",
                                title: "Kein Inventar",
                                subtitle: "Scanne einen Kassenzettel oder füge\nArtikel manuell hinzu.",
                                ctaLabel: "Artikel hinzufügen"
                            ) {
                                viewModel.showAddSheet = true
                            }
                        } else {
                            inventoryContent
                        }
                    }

                    if !viewModel.isMultiSelectActive {
                        AppFloatingActionButton(icon: "plus") {
                            viewModel.showAddSheet = true
                        }
                    }

                    if viewModel.isMultiSelectActive {
                        multiSelectBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Inventar")
            .searchable(text: $viewModel.searchText, prompt: "Suchen…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.toggleMultiSelect()
                        }
                    } label: {
                        Text(viewModel.isMultiSelectActive ? "Fertig" : "Auswählen")
                            .font(AppTypography.captionMedium)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileToolbarButton(
                        isAuthenticated: isAuthenticated,
                        isGoogleAccount: isGoogleAccount,
                        profileImageURL: profileImageURL,
                        action: onOpenAccount
                    )
                }
            }
            .refreshable { await viewModel.loadData() }
            .task { await viewModel.loadData() }
            .sheet(isPresented: $viewModel.showDetail) {
                if let item = viewModel.selectedItem {
                    ItemDetailSheet(item: item, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddInventoryItemSheet(viewModel: viewModel)
            }
        }
        .appToast(isPresented: $showDeleteToast, message: "Artikel gelöscht", icon: "trash")
        .confirmationDialog(
            "\(viewModel.selectedCount) Artikel löschen?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                Haptics.warning()
                Task {
                    await viewModel.deleteSelected()
                    withAnimation { showDeleteToast = true }
                }
            }
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
    }

    // MARK: - Location Filter Chips

    private var locationFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                locationChip(label: "Alle", location: nil)
                locationChip(label: StorageLocation.fridge.displayName, location: .fridge)
                locationChip(label: StorageLocation.pantry.displayName, location: .pantry)
                locationChip(label: StorageLocation.freezer.displayName, location: .freezer)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, 4)
        }
    }

    private func locationChip(label: String, location: StorageLocation?) -> some View {
        let isSelected = viewModel.selectedLocation == location
        return Button {
            viewModel.selectedLocation = location
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? Color.white : AppColors.primaryForeground.opacity(0.85))
                .background(isSelected ? AppColors.primary : AppColors.primary.opacity(0.3))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.white.opacity(0.18) : AppColors.primary.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Filter Chips

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(label: "Alle", isSelected: selectedCategoryFilter == nil) {
                    selectedCategoryFilter = nil
                }
                ForEach(usedCategories, id: \.self) { cat in
                    categoryChip(label: cat.displayName, isSelected: selectedCategoryFilter == cat) {
                        selectedCategoryFilter = (selectedCategoryFilter == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.s)
        }
    }

    private var usedCategories: [FoodCategory] {
        let cats = viewModel.filteredItems.compactMap { $0.category }
        return Array(Set(cats)).sorted { $0.displayName < $1.displayName }
    }

    private func categoryChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? Color.white : AppColors.primaryForeground.opacity(0.85))
                .background(isSelected ? AppColors.primary : AppColors.primary.opacity(0.3))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.white.opacity(0.18) : AppColors.primary.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content

    private var inventoryContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.m) {
                locationFilterChips

                HStack {
                    Text("Neueste Artikel")
                        .font(.system(size: 12, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Menu {
                        ForEach(InventorySortOption.allCases) { option in
                            Button {
                                selectedSortOption = option
                            } label: {
                                if selectedSortOption == option {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedSortOption.shortLabel)
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                }
                .padding(.top, AppSpacing.xs)

                if displayedItems.isEmpty {
                    listEmptyState
                } else {
                    ForEach(displayedItems) { item in
                        inventoryListRow(item)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, 0)
            .padding(.bottom, 90)
        }
    }

    private var displayedItems: [InventoryItem] {
        let filtered = viewModel.filteredItems.filter { item in
            guard let selectedCategoryFilter else { return true }
            return item.category == selectedCategoryFilter
        }

        switch selectedSortOption {
        case .newestFirst:
            return filtered.sorted { $0.purchaseDate > $1.purchaseDate }
        case .oldestFirst:
            return filtered.sorted { $0.purchaseDate < $1.purchaseDate }
        case .nameAZ:
            return filtered.sorted {
                DisplayNameFormatter.format($0.canonicalName).localizedCaseInsensitiveCompare(
                    DisplayNameFormatter.format($1.canonicalName)
                ) == .orderedAscending
            }
        case .expirySoonest:
            return filtered.sorted { lhs, rhs in
                let lhsDate = lhs.estimatedExpiryDate ?? .distantFuture
                let rhsDate = rhs.estimatedExpiryDate ?? .distantFuture
                return lhsDate < rhsDate
            }
        }
    }

    private var listEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.s) {
                Image(systemName: "tray")
                    .foregroundStyle(AppColors.textTertiary)
                Text(emptyStateMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }

            if isAnyFilterActive {
                Button {
                    selectedCategoryFilter = nil
                    viewModel.selectedLocation = nil
                    viewModel.searchText = ""
                } label: {
                    Text("Filter zurücksetzen")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
    }

    private var isAnyFilterActive: Bool {
        selectedCategoryFilter != nil || viewModel.selectedLocation != nil || !viewModel.searchText.isEmpty
    }

    private var emptyStateMessage: String {
        if isAnyFilterActive {
            return "Keine Artikel im aktuellen Filter."
        }
        return "Keine Artikel vorhanden."
    }

    private func inventoryListRow(_ item: InventoryItem) -> some View {
        HStack(spacing: AppSpacing.m) {
            ProductImageView(imageUrl: item.imageUrl, category: item.category, size: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(DisplayNameFormatter.format(item.canonicalName))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Label(item.location.displayName, systemImage: item.location.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)

                Text(item.expiryStatus.label)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(item.expiryStatus.color)
            }

            Spacer(minLength: 0)

            if viewModel.isMultiSelectActive {
                Image(systemName: viewModel.selectedIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(viewModel.selectedIds.contains(item.id) ? AppColors.primary : AppColors.textTertiary)
            } else {
                HStack(spacing: 8) {
                    quantityButton(icon: "minus", fill: Color.black.opacity(0.06)) {
                        Haptics.light()
                        Task { await viewModel.adjustQuantity(item, by: -1) }
                    }
                    Text(compactQuantity(for: item))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minWidth: 22)
                    quantityButton(icon: "plus", fill: AppColors.primary.opacity(0.2)) {
                        Haptics.light()
                        Task { await viewModel.adjustQuantity(item, by: 1) }
                    }
                }
            }
        }
        .padding(AppSpacing.m)
        .frame(minHeight: 94)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                        .stroke(AppColors.cardStroke, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isMultiSelectActive {
                withAnimation(.spring(response: 0.2)) {
                    viewModel.toggleSelection(item)
                }
            } else {
                viewModel.openDetail(item)
            }
        }
    }

    private func quantityButton(icon: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 30, height: 30)
                .background(fill)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func compactQuantity(for item: InventoryItem) -> String {
        let qty = item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)
        return qty
    }

    private var filteredLocationGroups: [InventoryViewModel.LocationGroup] {
        guard let cat = selectedCategoryFilter else {
            return viewModel.groupedByLocationAndCategory
        }
        return viewModel.groupedByLocationAndCategory.compactMap { locGroup in
            let filteredCatGroups = locGroup.categoryGroups.filter { $0.category == cat }
            guard !filteredCatGroups.isEmpty else { return nil }
            return InventoryViewModel.LocationGroup(
                location: locGroup.location,
                categoryGroups: filteredCatGroups
            )
        }
    }

    // MARK: - Urgent Section

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppSectionHeader(title: "Bald verwenden", icon: "exclamationmark.triangle.fill", iconColor: AppColors.warning)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.m) {
                    ForEach(viewModel.useFirstItems) { item in
                        urgentCard(item)
                    }
                }
            }
        }
    }

    private func urgentCard(_ item: InventoryItem) -> some View {
        Button {
            viewModel.openDetail(item)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack {
                    Text(DisplayNameFormatter.format(item.canonicalName))
                        .font(AppTypography.bodyMedium)
                        .lineLimit(1)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                }
                AppPillBadge(text: item.expiryStatus.label, color: item.expiryStatus.color)
                Text(quantityText(for: item))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.m)
            .frame(width: 155, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(item.expiryStatus.color.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Location Section

    private func locationSection(_ locGroup: InventoryViewModel.LocationGroup) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Label(locGroup.location.displayName, systemImage: locGroup.location.icon)
                    .font(AppTypography.title)
                Spacer()
                AppPillBadge(text: "\(locGroup.totalCount)", color: AppColors.textSecondary, style: .subtle)
            }
            .padding(.horizontal, AppSpacing.xs)

            VStack(spacing: AppSpacing.s) {
                ForEach(locGroup.categoryGroups) { catGroup in
                    categoryCard(catGroup, in: locGroup)
                }
            }
        }
    }

    private func categoryCard(
        _ catGroup: InventoryViewModel.CategoryGroup,
        in locGroup: InventoryViewModel.LocationGroup
    ) -> some View {
        AppCard(padding: AppSpacing.m, elevation: .none) {
            DisclosureGroup(isExpanded: binding(for: catGroup, in: locGroup)) {
                Divider().padding(.vertical, AppSpacing.xs)
                VStack(spacing: 0) {
                    ForEach(catGroup.items) { item in
                        HStack(spacing: AppSpacing.s) {
                            if viewModel.isMultiSelectActive {
                                Image(systemName: viewModel.selectedIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(viewModel.selectedIds.contains(item.id) ? AppColors.primary : AppColors.textTertiary)
                                    .animation(.spring(response: 0.2), value: viewModel.selectedIds.contains(item.id))
                            }
                            InventoryItemRow(item: item)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.isMultiSelectActive {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.2)) {
                                    viewModel.toggleSelection(item)
                                }
                            } else {
                                Haptics.selection()
                                viewModel.openDetail(item)
                            }
                        }
                        .contextMenu {
                            if !viewModel.isMultiSelectActive {
                                Button {
                                    viewModel.openDetail(item)
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Haptics.warning()
                                    Task {
                                        await viewModel.deleteItem(item)
                                        withAnimation { showDeleteToast = true }
                                    }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }

                        if item.id != catGroup.items.last?.id {
                            Divider().padding(.leading, viewModel.isMultiSelectActive ? 82 : 54)
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.s) {
                    AppIconBadge(
                        icon: AppColors.categoryIcon(for: catGroup.category),
                        color: AppColors.categoryColor(for: catGroup.category),
                        size: 28
                    )
                    Text(catGroup.category.displayName)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    AppPillBadge(
                        text: "\(catGroup.items.count)",
                        color: catGroup.hasUrgent ? AppColors.warning : AppColors.textSecondary,
                        style: .subtle
                    )
                }
                .padding(.vertical, AppSpacing.xs)
                .contentShape(Rectangle())
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: binding(for: catGroup, in: locGroup).wrappedValue)
        }
    }

    // MARK: - Multi-Select Bar

    private var multiSelectBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppSpacing.m) {
                Button {
                    if viewModel.selectedIds.count == viewModel.filteredItems.count {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                } label: {
                    Text(viewModel.selectedIds.count == viewModel.filteredItems.count ? "Keine" : "Alle")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.primary)
                }

                Spacer()

                if viewModel.selectedCount > 0 {
                    Text("\(viewModel.selectedCount) ausgewählt")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Menu {
                    ForEach(StorageLocation.allCases) { loc in
                        Button {
                            Haptics.medium()
                            Task { await viewModel.moveSelected(to: loc) }
                        } label: {
                            Label(loc.displayName, systemImage: loc.icon)
                        }
                    }
                } label: {
                    Image(systemName: "tray.2")
                        .font(.body.weight(.medium))
                        .foregroundStyle(viewModel.selectedCount > 0 ? AppColors.primary : AppColors.textTertiary)
                }
                .disabled(viewModel.selectedCount == 0)

                Button {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.medium))
                        .foregroundStyle(viewModel.selectedCount > 0 ? AppColors.danger : AppColors.textTertiary)
                }
                .disabled(viewModel.selectedCount == 0)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.m)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func quantityText(for item: InventoryItem) -> String {
        let qty = item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)
        return "\(qty) \(item.unit)"
    }

    private func binding(
        for catGroup: InventoryViewModel.CategoryGroup,
        in locGroup: InventoryViewModel.LocationGroup
    ) -> Binding<Bool> {
        let key = "\(locGroup.location.rawValue)_\(catGroup.category.rawValue)"
        return Binding(
            get: {
                if expandedCategories.contains(key) { return true }
                return catGroup.hasUrgent
            },
            set: { expanded in
                if expanded {
                    expandedCategories.insert(key)
                } else {
                    expandedCategories.remove(key)
                }
            }
        )
    }
}

private enum InventorySortOption: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst
    case nameAZ
    case expirySoonest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newestFirst:
            return "Neueste zuerst"
        case .oldestFirst:
            return "Älteste zuerst"
        case .nameAZ:
            return "Name A-Z"
        case .expirySoonest:
            return "Ablauf zuerst"
        }
    }

    var shortLabel: String {
        switch self {
        case .newestFirst:
            return "Neueste"
        case .oldestFirst:
            return "Älteste"
        case .nameAZ:
            return "Name A-Z"
        case .expirySoonest:
            return "Ablauf"
        }
    }
}

// MARK: - Add Item Sheet

struct AddInventoryItemSheet: View {
    @Bindable var viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Artikelname", text: $viewModel.newName)
                        .font(AppTypography.body)
                    HStack {
                        TextField("Menge", text: $viewModel.newQuantity)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 80)
                        Picker("Einheit", selection: $viewModel.newUnit) {
                            ForEach(["Stk", "kg", "g", "L", "ml"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section {
                    Picker("Lagerort", selection: $viewModel.newLocation) {
                        ForEach(StorageLocation.allCases) { loc in
                            Label(loc.displayName, systemImage: loc.icon).tag(loc)
                        }
                    }
                    Picker("Kategorie", selection: $viewModel.newCategory) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Neuer Artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { viewModel.resetAddForm() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        Haptics.success()
                        Task {
                            await viewModel.addManualItem()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(AppSpacing.cardRadiusLarge)
    }
}

// MARK: - Detail Sheet

struct ItemDetailSheet: View {
    @State var item: InventoryItem
    let viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEmptyToast = false

    var body: some View {
        NavigationStack {
            AppBackgroundView {
                ScrollView {
                    VStack(spacing: AppSpacing.m) {
                        headerCard
                        expiryCard
                        detailsCard
                        quantityActions
                        emptyAction
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.m)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle(DisplayNameFormatter.format(item.canonicalName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Haptics.success()
                        Task {
                            await viewModel.updateItem(item)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(AppSpacing.cardRadiusLarge)
        .appToast(isPresented: $showEmptyToast, message: "Zur Einkaufsliste hinzugefügt", icon: "cart.badge.plus")
    }

    // MARK: - Header

    private var headerCard: some View {
        AppCard {
            HStack(spacing: AppSpacing.m) {
                ProductImageView(imageUrl: item.imageUrl, category: item.category, size: 44)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(DisplayNameFormatter.format(item.canonicalName))
                        .font(AppTypography.headline2)
                    Text(item.category?.displayName ?? "Sonstiges")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                quantityPill
            }
        }
    }

    private var quantityPill: some View {
        let qtyText = item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)

        return Text("\(qtyText) \(item.unit)")
            .font(AppTypography.callout)
            .fontWeight(.medium)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.s + 2)
            .padding(.vertical, AppSpacing.xs + 1)
            .background(AppColors.textSecondary.opacity(0.08))
            .clipShape(Capsule())
    }

    // MARK: - Expiry

    private var expiryCard: some View {
        let status = item.expiryStatus

        return AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                HStack(spacing: AppSpacing.m) {
                    AppIconBadge(
                        icon: status.isExpired ? "xmark.circle.fill" : status.isSoon ? "exclamationmark.triangle.fill" : "clock.fill",
                        color: status.isUrgent ? status.color : AppColors.textSecondary,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haltbarkeit")
                            .font(AppTypography.bodyMedium)
                        if let d = item.estimatedExpiryDate {
                            Text(d, style: .date)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        } else {
                            Text("Kein Ablaufdatum")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                    Spacer()
                    if !status.shortLabel.isEmpty {
                        AppPillBadge(text: status.shortLabel, color: status.color)
                    }
                }

                Toggle("Ablaufdatum setzen", isOn: hasExpiryDateBinding)
                    .font(AppTypography.captionMedium)
                    .tint(AppColors.primary)

                if item.estimatedExpiryDate != nil {
                    DatePicker("Ablaufdatum", selection: expiryDateBinding, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
        }
    }

    // MARK: - Details

    private var detailsCard: some View {
        AppCard {
            VStack(spacing: 0) {
                detailRow("Lagerort", icon: "mappin") {
                    Picker("", selection: $item.location) {
                        ForEach(StorageLocation.allCases) { loc in
                            Text(loc.displayName).tag(loc)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppColors.textPrimary)
                }
                Divider().padding(.leading, 40)
                detailRow("Kategorie", icon: "tag") {
                    Picker("", selection: categoryBinding) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppColors.textPrimary)
                }
                Divider().padding(.leading, 40)
                HStack {
                    Image(systemName: item.opened ? "lock.open.fill" : "lock.fill")
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 24)
                    Toggle("Geöffnet", isOn: $item.opened)
                        .font(AppTypography.callout)
                        .tint(AppColors.primary)
                }
                .padding(.vertical, AppSpacing.s)
            }
        }
    }

    private func detailRow<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 24)
            Text(title)
                .font(AppTypography.callout)
                .layoutPriority(1)
            Spacer(minLength: AppSpacing.s)
            content()
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: AppSpacing.minTapTarget)
    }

    // MARK: - Quantity Actions

    private var quantityActions: some View {
        AppCard(padding: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("Menge anpassen")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: AppSpacing.s) {
                    qtyButton("−1", icon: "minus") {
                        Haptics.medium()
                        Task { await viewModel.adjustQuantity(item, by: -1); dismiss() }
                    }
                    qtyButton("+1", icon: "plus") {
                        Haptics.light()
                        Task { await viewModel.adjustQuantity(item, by: 1); dismiss() }
                    }
                    qtyButton("½", icon: "divide") {
                        Haptics.light()
                        Task { await viewModel.halfConsumed(item); dismiss() }
                    }
                }
            }
        }
    }

    private func qtyButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(AppTypography.captionMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.m)
            .background(AppColors.textSecondary.opacity(0.06))
            .foregroundStyle(AppColors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
        }
        .buttonStyle(QtyButtonStyle())
    }

    // MARK: - Empty Action

    private var emptyAction: some View {
        Button {
            Haptics.warning()
            withAnimation { showEmptyToast = true }
            Task { await viewModel.setEmpty(item); dismiss() }
        } label: {
            HStack(spacing: AppSpacing.m) {
                Image(systemName: "arrow.right.circle")
                    .font(.body.weight(.medium))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Leer markieren")
                        .font(AppTypography.bodyMedium)
                    Text("Zur Einkaufsliste hinzufügen")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
            }
            .padding(AppSpacing.m)
            .foregroundStyle(AppColors.warning)
            .background(AppColors.warning.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius, style: .continuous)
                    .strokeBorder(AppColors.warning.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(QtyButtonStyle())
    }

    private var categoryBinding: Binding<FoodCategory> {
        Binding(
            get: { item.category ?? .other },
            set: { item.category = $0 }
        )
    }

    private var hasExpiryDateBinding: Binding<Bool> {
        Binding(
            get: { item.estimatedExpiryDate != nil },
            set: { enabled in
                if enabled {
                    item.estimatedExpiryDate = item.estimatedExpiryDate ?? Calendar.current.date(byAdding: .day, value: 7, to: .now)
                } else {
                    item.estimatedExpiryDate = nil
                }
            }
        )
    }

    private var expiryDateBinding: Binding<Date> {
        Binding(
            get: { item.estimatedExpiryDate ?? .now },
            set: { item.estimatedExpiryDate = $0 }
        )
    }
}

private struct QtyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    InventoryView(store: InventoryStore(
        repository: PreviewInventoryRepository()
    ))
}

private struct PreviewInventoryRepository: InventoryRepositoryProtocol {
    func fetchAll() async throws -> [InventoryItem] {
        [
            InventoryItem(canonicalName: "Milch", quantity: 1, unit: "L", location: .fridge,
                          estimatedExpiryDate: Calendar.current.date(byAdding: .day, value: 2, to: .now), category: .dairy),
            InventoryItem(canonicalName: "Spaghetti", quantity: 2, unit: "Stk", location: .pantry, category: .grains),
        ]
    }
    func save(_ item: InventoryItem) async throws {}
    func saveAll(_ items: [InventoryItem]) async throws {}
    func replaceAll(with items: [InventoryItem]) async throws {}
    func delete(_ item: InventoryItem) async throws {}
    func update(_ item: InventoryItem) async throws {}
    func syncWithRemote() async throws {}
}
