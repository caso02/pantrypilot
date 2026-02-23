# PantryPilot Backend

Backend-Service für die PantryPilot iOS-App. Baut eine interne Migros-Produktdatenbank auf und bietet Such- und Matching-Endpoints für Kassenzettel-Zeilen.

## Tech Stack

- **Runtime**: Node.js 20+ / TypeScript
- **HTTP**: Fastify 5
- **Datenbank**: PostgreSQL 16 (Prisma ORM)
- **Queue**: Redis 7 + BullMQ
- **Validierung**: Zod
- **Tests**: Vitest
- **Migros-Daten**: [migros-api-wrapper](https://github.com/aliyss/migros-api-wrapper) (inoffiziell)

## Architektur

```
apps/api/src/
├── config/       Umgebungsvariablen (Zod-validiert)
├── db/           Prisma- und Redis-Clients
├── jobs/         BullMQ Queues, Sync-Worker, Scheduler
├── migros/       Wrapper um migros-api-wrapper
├── routes/       Fastify Route-Handler
├── services/     Business-Logik (Produkte, Matching, Normalisierung)
├── utils/        Normalisierung, Tokenisierung, Scoring, Retry
├── app.ts        Fastify-App-Konfiguration
└── server.ts     Entry-Point
```

Alle Migros-API-Aufrufe passieren serverseitig. Die iOS-App kommuniziert nur mit diesem Backend.

## Lokale Entwicklung

### Voraussetzungen

- Docker + Docker Compose
- Node.js 20+ (für lokale Entwicklung ohne Docker)

### Mit Docker starten

```bash
cd backend/docker
docker compose up -d
```

Dies startet PostgreSQL, Redis und den API-Service. Die API ist unter `http://localhost:3000` erreichbar.

### Ohne Docker (lokal)

1. PostgreSQL und Redis lokal starten
2. `.env`-Datei erstellen:

```bash
cp docker/.env.example apps/api/.env
```

3. Dependencies installieren und DB migrieren:

```bash
cd apps/api
npm install
npx prisma migrate dev --schema=../../prisma/schema.prisma
```

4. Server starten:

```bash
npm run dev
```

### Datenbank mit Produkten befüllen (Seed)

```bash
cd apps/api
npm run seed
```

Sucht nach ~15 gängigen Kategorien bei Migros und speichert die Ergebnisse in der DB.

### Tests ausführen

```bash
cd apps/api
npm test
```

## API-Endpoints

### `GET /v1/health`

```bash
curl http://localhost:3000/v1/health
# {"ok":true,"timestamp":"2026-02-23T..."}
```

### `GET /v1/products/search?q=Milch`

Sucht zuerst in der lokalen DB. Falls wenige Treffer, wird automatisch die Migros-API abgefragt und die Ergebnisse gespeichert.

```bash
curl "http://localhost:3000/v1/products/search?q=Milch"
```

Response:

```json
{
  "results": [
    {
      "id": "uuid",
      "canonicalName": "M-Classic Vollmilch",
      "name": "M-CLASSIC VOLLMILCH",
      "ean": "7616800123456",
      "unitText": "1 l",
      "categoryPath": ["Milchprodukte", "Milch"],
      "imageUrl": "https://...",
      "score": 0.85
    }
  ]
}
```

### `POST /v1/products/match`

Matcht Kassenzettel-Zeilen gegen die Produktdatenbank. Kernfeature für PantryPilot.

```bash
curl -X POST http://localhost:3000/v1/products/match \
  -H "Content-Type: application/json" \
  -d '{
    "merchant": "migros",
    "lines": [
      { "rawText": "M-CLASSIC MILCH 1L", "priceText": "1.60" },
      { "rawText": "BIO JOGHURT NATURE 500G", "priceText": "2.95" }
    ]
  }'
```

Response:

```json
{
  "matches": [
    {
      "rawText": "M-CLASSIC MILCH 1L",
      "rawKey": "M-CLASSIC MILCH",
      "suggestions": [
        {
          "productId": "uuid",
          "canonicalName": "M-Classic Milch",
          "unitText": "1 l",
          "categoryPath": ["Milchprodukte"],
          "score": 0.92
        }
      ]
    }
  ]
}
```

### `POST /v1/receipts/parse` (NEU – LLM-gestützt)

Interpretiert abgekürzte Kassenzettel-Zeilen via LLM und matcht sie gegen die Produktdatenbank. Erfordert `OPENAI_API_KEY` oder `ANTHROPIC_API_KEY`.

```bash
curl -X POST http://localhost:3000/v1/receipts/parse \
  -H "Content-Type: application/json" \
  -d '{
    "lines": [
      "M-CL VOLLM UHT 1L",
      "OPTIG POULETBR 400G",
      "BIO JOGH NAT 500",
      "FARMER SOFT CHOC"
    ],
    "autoMatch": true,
    "autoLearn": true
  }'
```

Response:

```json
{
  "parsed": [
    {
      "rawText": "M-CL VOLLM UHT 1L",
      "llm": {
        "productName": "M-Classic Vollmilch UHT",
        "brand": "M-Classic",
        "quantity": 1,
        "unit": "L",
        "category": "Milchprodukte",
        "confidence": "high"
      },
      "match": {
        "productId": "uuid",
        "canonicalName": "M-Classic · Vita Milch · 1.5% Fett, Calcium",
        "unitText": "1l",
        "categoryPath": ["Milchprodukte", "Milch"],
        "score": 0.72
      }
    }
  ],
  "stats": { "total": 4, "matched": 3, "highConfidence": 3 }
}
```

**Flow**: Rohtext → LLM interpretiert Abkürzungen → DB-Match → Auto-Learn (speichert erfolgreiche Zuordnungen).

Der bestehende `POST /v1/products/match` nutzt den LLM automatisch als Fallback, wenn direkte Matches zu schwach sind (score < 0.4). Kann mit `"useLLM": false` deaktiviert werden.

### `POST /v1/normalization/override`

Speichert manuelle Korrekturen (Learning Loop aus der iOS-App).

```bash
curl -X POST http://localhost:3000/v1/normalization/override \
  -H "Content-Type: application/json" \
  -d '{
    "rawText": "M-CL VOLLM UHT 1L",
    "canonicalName": "M-Classic Vollmilch UHT",
    "categoryHint": "Milchprodukte"
  }'
```

## Authentifizierung

Optional: Setze `API_KEY` als Umgebungsvariable. Wenn gesetzt, muss jeder Request (ausser `/v1/health`) den Header `x-api-key` mitschicken:

```bash
curl -H "x-api-key: dein-secret-key" http://localhost:3000/v1/products/search?q=Milch
```

Ohne `API_KEY` in der Umgebung ist die API offen (Dev-Modus).

## Hintergrund-Jobs

- **Nightly Refresh**: Läuft täglich um 03:00 und aktualisiert Produkte für ~30 gängige Suchbegriffe
- **Search Enrich**: Wird automatisch getriggert wenn der Match-Endpoint keine guten Treffer findet

Jobs werden über BullMQ/Redis verwaltet mit exponential Backoff und max. Concurrency 2.

## Normalisierung & Matching

### Ablauf beim Matching (mit LLM)

1. `rawText` → `rawKey` (Preise/Zahlen entfernen, uppercase, trimmen)
2. Prüfe `ReceiptLineNormalization`-Overrides (manuelle Korrekturen → sofort Score 1.0)
3. Suche in `ProductAlias`-Tabelle
4. Suche über Keyword-Overlap in `Product`-Tabelle
5. Scoring: 50% Jaccard + 30% Prefix-Match + 20% Levenshtein
6. **NEU**: Falls Score < 0.4 und LLM konfiguriert → LLM interpretiert Abkürzungen → Re-Match mit vollem Produktnamen
7. **Auto-Learn**: Erfolgreiche LLM-Matches werden als Normalization-Overrides gespeichert → nächstes Mal direkt erkannt (Schritt 2)
8. Falls immer noch keine guten Treffer: Remote-Suche via Migros-API enqueuen

### Alias-Dictionary erweitern

Aliase werden automatisch bei jedem Migros-Import erstellt. Manuell:

```sql
INSERT INTO product_aliases (id, product_id, alias, source)
VALUES (gen_random_uuid(), '<product-uuid>', 'VOLLM UHT', 'seed');
```

### Normalisierungs-Overrides

Über den `/v1/normalization/override` Endpoint oder direkt in der DB:

```sql
INSERT INTO receipt_line_normalizations (id, raw_key, canonical_name, category_hint, updated_at)
VALUES (gen_random_uuid(), 'M-CL VOLLM UHT', 'M-Classic Vollmilch UHT', 'Milchprodukte', NOW());
```

## Hinweise

- **migros-api-wrapper** ist ein inoffizielles Community-Projekt. Die Migros-API kann sich jederzeit ändern. Deshalb speichern wir alle Produktdaten lokal und sind nicht von Echtzeit-Verfügbarkeit abhängig.
- Die Guest-Token-Authentifizierung funktioniert ohne Login. Für Cumulus-Daten wäre ein Login nötig (nicht implementiert).
- Rate-Limiting ist eingebaut (max 4 Requests/5s an Migros, Concurrency 2).

## Umgebungsvariablen

| Variable | Default | Beschreibung |
|---|---|---|
| `DATABASE_URL` | — | PostgreSQL Connection String |
| `REDIS_URL` | `redis://localhost:6379` | Redis Connection String |
| `PORT` | `3000` | Server-Port |
| `NODE_ENV` | `development` | `development` / `production` / `test` |
| `API_KEY` | — | Optional: API-Key für Authentifizierung |
| `MIGROS_REGION` | `national` | Migros-Region |
| `MIGROS_LANGUAGE` | `de` | Sprache (`de`, `fr`, `it`, `en`) |
| `LLM_PROVIDER` | `openai` | `openai` oder `anthropic` |
| `OPENAI_API_KEY` | — | OpenAI API-Key (für GPT-4o-mini) |
| `ANTHROPIC_API_KEY` | — | Anthropic API-Key (für Claude Haiku) |
| `LLM_MODEL` | auto | Modell-Override (Default: `gpt-4o-mini` / `claude-3-5-haiku-latest`) |
