# PantryPilot

Lebensmittel-Inventar aus Kassenzettel-Scans – iOS-App mit SwiftUI, lokalisiert für die Schweiz (Migros / CHF).

## Voraussetzungen

- Xcode 15.0+ (Swift 5.9)
- iOS 17.0+ Deployment Target
- macOS Sonoma oder neuer

## Projekt einrichten

```bash
# XcodeGen installieren (falls nicht vorhanden)
brew install xcodegen

# Xcode-Projekt generieren
cd kassenzettel
xcodegen generate

# Projekt in Xcode öffnen
open PantryPilot.xcodeproj
```

## Mock-Modus

Der Mock-Modus liefert simulierte API-Antworten (MIGROS-Kassenbon mit Schweizer Artikeln) ohne Server.

### Aktivierung

**Option 1** – In der App: Tab "Einstellungen" → "Mock API verwenden" → App neu starten.

**Option 2** – Umgebungsvariable: In Xcode → Product → Scheme → Edit Scheme → Run → Environment Variables → `USE_MOCK_API` = `1`.

### Mock-Scan-Flow
1. Mock-Modus aktivieren
2. Tab "Scan" öffnen → "Scan starten"
3. Platzhalterbild wird angezeigt → "Analysieren"
4. 10 Zeilen erscheinen (8 Artikel + 2 Non-Food: PFAND, SACK GEBÜHR)
5. Non-Food-Zeilen sind automatisch als "Ignoriert" markiert
6. Artikel einzeln antippen → Name, Kategorie, Lagerort, Menge bearbeiten
7. "Alle → Kühlschrank" über das Lagerort-Menü oben rechts
8. Bestätigen → Artikel werden zum Inventar hinzugefügt mit Ablaufschätzung

## Schweizer Lokalisierung

- **Währung**: CHF via `CurrencyFormatter.formatMoney(amount:)` – verwendet `de_CH` Locale
- **Händler**: MIGROS in Mock-Daten (statt REWE)
- **Artikel**: Schweizer Bezeichnungen (Rüebli, Pouletbrust, Zopf, M-Classic, etc.)
- **Abkürzungen**: `NormalizationService.abbreviations` enthält CH-spezifische Einträge

### Neue Migros-Abkürzungen hinzufügen

In `PantryPilot/Domain/UseCases/NormalizationService.swift`:
```swift
private let abbreviations: [String: String] = [
    // Bestehende Einträge...
    "rüebli": "Karotten",
    "poulet": "Poulet",
    "zopf": "Zopf",
    "m-classic": "M-Classic",
    "m-budget": "M-Budget",
    // Hier neue hinzufügen:
    "neuerabk": "Voller Name",
]
```

### Normalisierungs-Mappings (Learning Loop)

Wenn Benutzer im Scan-Bestätigungsschritt einen Artikelnamen oder eine Kategorie korrigieren, wird das Mapping in SwiftData gespeichert (`PersistedNormalizationMapping`). Beim nächsten Scan mit demselben Rohtext wird das gelernte Mapping automatisch verwendet.

## Architektur

```
PantryPilot/
├── App/                          # App-Einstiegspunkt
├── Core/
│   ├── Camera/                   # AVFoundation Kamera-Service
│   ├── DI/                       # Dependency Injection Container
│   ├── Networking/               # URLSession-Client, Retry, Errors
│   ├── Notifications/            # Local + Push Notifications
│   └── Utils/                    # Keychain, Logger, CurrencyFormatter, Haptics
├── Data/
│   ├── API/                      # Mock-Client, Endpoint-Definitionen
│   ├── Persistence/              # SwiftData-Modelle + NormalizationMapping
│   └── Repositories/             # Konkrete Repository-Implementierungen
├── Domain/
│   ├── Models/                   # Datenmodelle + ExpiryStatus
│   ├── Protocols/                # Repository-Interfaces
│   └── UseCases/                 # Normalisierung (mit Learning Loop), Ablauf, Low-Stock
├── Presentation/
│   ├── DesignSystem/
│   │   ├── Tokens/               # AppColors, AppTypography, AppSpacing
│   │   └── Components/           # AppCard, AppPillBadge, AppIconBadge, AppToast, …
│   ├── ViewModels/               # MVVM ViewModels (@Observable)
│   └── Views/                    # SwiftUI Views (5 Tabs)
├── Resources/
│   ├── Assets.xcassets/          # App-Icons, Farben
│   └── MockData/                 # Beispiel-JSON (MIGROS/CHF)
└── Stores/                       # SessionStore, InventoryStore (mit Dedupe)
```

## Design System

Das Design System liegt unter `Presentation/DesignSystem/` und enthält Tokens und wiederverwendbare Komponenten.

### Tokens (Farben, Typografie, Abstände anpassen)

| Datei | Inhalt |
|-------|--------|
| `Tokens/AppColors.swift` | Semantische Farben (primary, surface, success/warning/danger, …) – passen sich an Light/Dark an |
| `Tokens/AppTypography.swift` | Typografie-Stufen (headline1/2, title, body, caption, metric) – alle mit `.system` + Dynamic Type |
| `Tokens/AppSpacing.swift` | Abstände (xs/s/m/l/xl/xxl), Corner Radii (12/16/20/24), Min-Tap-Target (44pt) |

### Komponenten

| Komponente | Beschreibung |
|------------|--------------|
| `AppCard` | Material-Karte mit Schatten, Rahmen, konfigurierbarem Padding |
| `AppIconBadge` | Abgerundetes Icon-Badge mit Tint-Hintergrund |
| `AppPillBadge` | Kompakte Pill für Ablaufstatus, Tags |
| `AppSectionHeader` | Einheitliche Sektions-Titel mit optionalem Icon und Trailing-Action |
| `AppEmptyState` | Freundliche Leer-Zustände mit Icon, Titel, Subtitle, optionalem CTA |
| `AppPrimaryButtonStyle` / `AppSecondaryButtonStyle` | Abgerundete Buttons mit Press-Animation |
| `AppFloatingActionButton` | FAB mit Schatten und Spring-Animation |
| `AppToast` | Overlay-Toast mit optionalem Rückgängig-Button |
| `AppBackgroundView` | Subtiler Gradient-Hintergrund |
| `LoadingSkeletonView` | Shimmer-Skeleton-Platzhalter |

## Tabs

| Tab | Funktion |
|-----|----------|
| **Inventar** | Gruppiert nach Lagerort → Kategorie (collapsible). "Bald verwenden"-Sektion oben. Detail-Sheet mit Schnellaktionen (Halb verbraucht, Leer, ±Menge). |
| **Scan** | Kassenzettel scannen → analysieren → Artikel bearbeiten/ignorieren → bestätigen → Inventar + Notifications. Learning Loop speichert Korrekturen. |
| **Einkaufsliste** | Dedupliziert nach Name+Einheit. Top-5-Vorschläge mit "Alle anzeigen". |
| **Übersicht** | Konkrete Metriken: "X Artikel bald ablaufend (≤3 Tage)", "Zuerst verwenden"-Liste, Lagerort-/Kategorie-Aufschlüsselung. |
| **Einstellungen** | Benachrichtigungen, Privatsphäre, Mock-API, Konto. |

## Tests

```bash
xcodebuild test -project PantryPilot.xcodeproj -scheme PantryPilot \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

- `NormalizationServiceTests` – Bereinigung, CH-Abkürzungen, Non-Food-Erkennung, Mapping-Priorität
- `ExpiryEstimationServiceTests` – Ablauf-Berechnungen
- `ExpiryStatusTests` – ExpiryStatus enum: fresh/soon/expired/unknown, Labels, Farben
- `CurrencyFormatterTests` – CHF-Formatierung
- `ShoppingListDedupeTests` – Deduplizierung nach Name+Einheit, Case-Insensitiv, Completed-Items
- `RepositoryTests` – Repository-Protokolle mit Mocks
- `LowStockSuggestionServiceTests` – Nachkauf-Logik

## Nächste Schritte

- [ ] Backend-API implementieren und echte Endpunkte anbinden
- [ ] OCR on-device mit Vision Framework als Offline-Fallback
- [ ] Barcode-Scanner für Produkterkennung
- [ ] iCloud Sync für Multi-Device
- [ ] Widgets für bald ablaufende Artikel
- [ ] "Gekauft → zum Inventar?" Flow in Einkaufsliste
- [ ] Angebots-Integration mit Migros-API
- [ ] Rezeptvorschläge basierend auf Inventar
