import { getEnv } from "../config/env.js";

export interface ParsedReceiptLine {
  rawText: string;
  productName: string;
  brand: string | null;
  quantity: number | null;
  unit: string | null;
  unitPrice: number | null;
  category: string | null;
  confidence: "high" | "medium" | "low";
}

interface LoggerLike {
  debug: (obj: unknown, msg?: string) => void;
  warn: (obj: unknown, msg?: string) => void;
}

const SYSTEM_PROMPT = `Du bist ein Experte für Schweizer Supermarkt-Kassenzettel (Migros, Coop, Aldi, Lidl, Denner).
Deine Aufgabe: Extrahiere ALLE Produkte aus OCR-Daten eines Kassenzettels.

WICHTIG - OCR-Spaltenformat:
Die OCR erkennt Kassenzettel oft SPALTENWEISE statt zeilenweise:
- Eine Zeile enthält ALLE Produktnamen hintereinander (z.B. "Erdbeeren Zwiebeln rot Bio Peperoni...")
- Eine andere Zeile enthält ALLE Preise hintereinander
- Die Produktnamen sind über MEHRERE OCR-Zeilen verteilt!

PRODUKTE TRENNEN:
- Jeder Produktname auf einem Kassenzettel ist ein EINZELNER Artikel (z.B. "Bio Birnen Williams" ist EIN Produkt, "Zwiebeln rot" ist ein ANDERES)
- Achte auf Migros-Kürzel: M-CL/MClass/MClas = M-Classic, M-BU/MBud = M-Budget, MBud Hostnockli = M-Budget Mostnöckli
- Thony = Thomy, Tortell. = Tortellini, Ric. = Ricotta, Atl. = Atlantischer, VALFL = Valflora
- "Bio Tête de Moine Rose" ist EIN Produkt (inkl. "Rose")
- "Chiefs Pudding Choco" und "Chiefs Pudding Stracci" sind ZWEI separate Produkte
- "YOU IPS BlumenkohlReis" ist EIN Produkt
- "Schne12kase"/"Schnelzkäse" = "Schmelzkäse"

MENGEN:
- Standard-Menge = 1
- Wenn eine Zahl direkt vor dem Produktnamen steht (z.B. "2 MBud Brötlilachs"), ist das die Menge

Kategorien: Milchprodukte, Fleisch, Fisch, Gemüse, Früchte, Brot/Backwaren, Getränke, Tiefkühl, Konserven, Gewürze/Saucen, Süsswaren, Snacks, Haushalt, Hygiene, Sonstiges

Ignorieren (KEINE Produkte): Totale, Zahlungen, MwSt, Barcodes, Header, Footer, "Sie sparen", Cumulus, Filiale, Bedien., KNr, "Total CHF", "Total in EUR", "Bar CHF", "Zurück", "Zwischentotal"

Antwortformat: Gib ausschliesslich ein JSON-Array zurück, keine Erklärungen.`;

function buildUserPrompt(lines: string[], priceList: number[]): string {
  const numbered = lines.map((l, i) => `Zeile ${i + 1}: "${l}"`).join("\n");

  const estimatedCount = estimateProductCount(lines);
  const priceContext = priceList.length > 0
    ? `\nAus der Preis-Spalte wurden ${priceList.length} Preise extrahiert (gleiche Reihenfolge wie Produkte):
${priceList.map((p, i) => `  ${i + 1}. ${p.toFixed(2)} CHF`).join("\n")}
Die OCR kann Preise falsch lesen. Ordne die Preise den Produkten in der gleichen Reihenfolge zu.
Falls es MEHR Produkte als Preise gibt: schätze fehlende Preise basierend auf typischen Schweizer Supermarkt-Preisen.\n`
    : "";
  const countHint = estimatedCount > 5
    ? `Dieser Kassenzettel hat ungefähr ${estimatedCount} Produkte.`
    : "";

  return `Extrahiere ALLE Produkte aus diesen OCR-Zeilen eines Schweizer Supermarkt-Kassenzettels:

${numbered}
${priceContext}
AUFGABE:
- Finde ALLE Produkte. ${countHint}
- Produktnamen sind über MEHRERE OCR-Zeilen verteilt! Durchsuche JEDE Zeile.
- Die "Artikelbezeichnung"-Zeile enthält NICHT alle Produkte — weitere stehen in separaten Zeilen (z.B. vor "Total in EUR", "Sie sparen" etc.).
- Trenne die Produktnamen korrekt: Jeder Eintrag auf dem Kassenzettel ist ein separater Artikel.
- Wenn ein Produkt doppelt auf dem Kassenzettel steht (z.B. "MClass Serrano Rohsch." 2x), gib es auch 2x zurück.
- JEDES Produkt MUSS einen unitPrice > 0 haben! Nutze die Preis-Spalte in derselben Reihenfolge.
- Falls Preise fehlen (OCR-Fehler): schätze den Preis realistisch für ein Schweizer Supermarkt-Produkt (z.B. Erdbeeren ~4.90, Schmelzkäse ~2.50).

Gib ein JSON-Array zurück:
[{"rawText":"OCR-Kürzel","productName":"Voller Name","brand":"Marke oder null","quantity":1,"unit":"Stk","unitPrice":3.50,"category":"Kategorie","confidence":"high|medium|low"}]`;
}

function estimateProductCount(lines: string[]): number {
  let bestCount = 0;
  for (const line of lines) {
    const lower = line.toLowerCase();
    if (lower.includes("total") || lower.includes("preis") || lower.includes("gespart")) {
      const allNums = line.match(/\d+[.,:]?\d{2}/g);
      if (allNums && allNums.length > bestCount) {
        bestCount = allNums.length;
      }
    }
  }
  if (bestCount > 3) {
    bestCount -= 2;
  }
  return bestCount;
}

async function callOpenAI(
  systemPrompt: string,
  userPrompt: string,
  model: string,
  apiKey: string
): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.1,
      max_tokens: 8192,
      response_format: { type: "json_object" },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`OpenAI API error ${res.status}: ${body}`);
  }

  const data: any = await res.json();
  return data.choices?.[0]?.message?.content ?? "[]";
}

async function callAnthropic(
  systemPrompt: string,
  userPrompt: string,
  model: string,
  apiKey: string
): Promise<string> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: 8192,
      system: systemPrompt,
      messages: [{ role: "user", content: userPrompt }],
      temperature: 0.1,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Anthropic API error ${res.status}: ${body}`);
  }

  const data: any = await res.json();
  const textBlock = data.content?.find((b: any) => b.type === "text");
  return textBlock?.text ?? "[]";
}

function extractJSONRaw(raw: string): any[] {
  let cleaned = raw.trim();
  cleaned = cleaned.replace(/^```json?\s*/i, "").replace(/```\s*$/, "");

  let parsed: any;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    const match = cleaned.match(/\[[\s\S]*\]/);
    if (match) {
      parsed = JSON.parse(match[0]);
    } else {
      throw new Error("Could not parse LLM response as JSON");
    }
  }

  const items: any[] = Array.isArray(parsed)
    ? parsed
    : parsed.items ?? parsed.lines ?? parsed.results ?? parsed.result ?? parsed.data ?? parsed.parsed ?? parsed.products ?? parsed.slots ??
      (Object.values(parsed).find((v) => Array.isArray(v)) as any[] ?? []);

  return items;
}


async function callPerplexity(
  systemPrompt: string,
  userPrompt: string,
  model: string,
  apiKey: string
): Promise<string> {
  const res = await fetch("https://api.perplexity.ai/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.1,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Perplexity API error ${res.status}: ${body}`);
  }

  const data: any = await res.json();
  return data.choices?.[0]?.message?.content ?? "[]";
}

async function callGemini(
  systemPrompt: string,
  userPrompt: string,
  model: string,
  apiKey: string
): Promise<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents: [{ parts: [{ text: userPrompt }] }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Gemini API error ${res.status}: ${body}`);
  }

  const data: any = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";
}

export function isLLMConfigured(): boolean {
  const env = getEnv();
  if (env.LLM_PROVIDER === "openai" && env.OPENAI_API_KEY) return true;
  if (env.LLM_PROVIDER === "anthropic" && env.ANTHROPIC_API_KEY) return true;
  if (env.LLM_PROVIDER === "perplexity" && env.PERPLEXITY_API_KEY) return true;
  if (env.LLM_PROVIDER === "gemini" && env.GEMINI_API_KEY) return true;
  return false;
}

export async function parseReceiptLines(
  rawLines: string[],
  logger?: LoggerLike
): Promise<ParsedReceiptLine[]> {
  const env = getEnv();

  if (!isLLMConfigured()) {
    throw new Error(
      "No LLM configured. Set OPENAI_API_KEY, ANTHROPIC_API_KEY, PERPLEXITY_API_KEY, or GEMINI_API_KEY."
    );
  }

  const { prices: priceList, totals: totalList } = extractPriceAndTotalColumns(rawLines, logger);
  logger?.debug(
    {
      inputLineCount: rawLines.length,
      priceCount: priceList.length,
      totalCount: totalList.length,
    },
    "Parsed OCR price columns"
  );

  const userPrompt = buildUserPrompt(rawLines, priceList);
  let response: string;

  if (env.LLM_PROVIDER === "openai" && env.OPENAI_API_KEY) {
    const model = env.LLM_MODEL ?? "gpt-4o-mini";
    response = await callOpenAI(SYSTEM_PROMPT, userPrompt, model, env.OPENAI_API_KEY);
  } else if (env.LLM_PROVIDER === "anthropic" && env.ANTHROPIC_API_KEY) {
    const model = env.LLM_MODEL ?? "claude-3-5-haiku-latest";
    response = await callAnthropic(SYSTEM_PROMPT, userPrompt, model, env.ANTHROPIC_API_KEY);
  } else if (env.LLM_PROVIDER === "perplexity" && env.PERPLEXITY_API_KEY) {
    const model = env.LLM_MODEL ?? "sonar";
    response = await callPerplexity(SYSTEM_PROMPT, userPrompt, model, env.PERPLEXITY_API_KEY);
  } else if (env.LLM_PROVIDER === "gemini" && env.GEMINI_API_KEY) {
    const model = env.LLM_MODEL ?? "gemini-2.0-flash";
    response = await callGemini(SYSTEM_PROMPT, userPrompt, model, env.GEMINI_API_KEY);
  } else {
    throw new Error("LLM provider not configured");
  }

  logger?.debug({ llmResponsePreview: response.substring(0, 1500) }, "LLM raw response preview");
  const rawItems = extractJSONRaw(response);
  logger?.debug(
    {
      llmItemCount: rawItems.length,
      items: rawItems.map((p: any) => `${p.productName} (qty=${p.quantity}, pos=${p.position})`),
    },
    "LLM parsed items"
  );

  let sorted = rawItems;
  if (rawItems.some((r: any) => r.position != null)) {
    sorted = [...rawItems].sort((a: any, b: any) => (a.position ?? 999) - (b.position ?? 999));
  }

  const parsed = sorted.map((item: any) => ({
    rawText: item.rawText ?? item.raw_text ?? "",
    productName: item.productName ?? item.product_name ?? item.name ?? "",
    brand: item.brand ?? null,
    quantity: item.quantity != null ? Number(item.quantity) : null,
    unit: item.unit ?? null,
    unitPrice: item.unitPrice != null ? Number(item.unitPrice) : (item.unit_price != null ? Number(item.unit_price) : null),
    category: item.category ?? null,
    confidence: (["high", "medium", "low"].includes(item.confidence) ? item.confidence : "medium") as ParsedReceiptLine["confidence"],
  }));

  const seen = new Map<string, number>();
  const deduped: typeof parsed = [];
  for (const item of parsed) {
    const key = item.productName.toLowerCase().trim();
    const count = seen.get(key) ?? 0;
    if (count >= 2) {
      logger?.warn({ productName: item.productName }, "Duplicate product removed (3rd+)");
      continue;
    }
    seen.set(key, count + 1);
    deduped.push(item);
  }

  const final = deduped;

  if (priceList.length > 0) {
    assignPrices(final, priceList, totalList, logger);
  }

  return final;
}

function assignPrices(
  items: ParsedReceiptLine[],
  priceList: number[],
  totalList: number[],
  logger?: LoggerLike
): void {
  if (items.length === priceList.length) {
    for (let i = 0; i < items.length; i++) {
      items[i].unitPrice = priceList[i];
      const total = totalList[i];
      if (total > 0 && Math.abs(total - priceList[i]) > 0.05 && priceList[i] > 0) {
        items[i].quantity = Math.round(total / priceList[i]);
      }
    }
    logger?.debug(
      { mode: "exact", items: items.map(p => `${p.productName} ${p.unitPrice}`) },
      "Assigned prices to parsed items"
    );
    return;
  }

  const llmHasPrices = items.filter(i => i.unitPrice != null && i.unitPrice > 0).length;
  const llmCoverage = llmHasPrices / items.length;

  if (llmCoverage >= 0.8) {
    logger?.debug(
      { mode: "llm", llmHasPrices, itemCount: items.length, coverage: llmCoverage },
      "Using LLM-assigned prices"
    );
    return;
  }

  if (llmCoverage >= 0.5) {
    const missing = items.filter(i => !i.unitPrice || i.unitPrice <= 0);
    // Count how often each price was already assigned by the LLM
    const usedPriceCounts = new Map<number, number>();
    for (const item of items) {
      if (item.unitPrice && item.unitPrice > 0) {
        usedPriceCounts.set(item.unitPrice, (usedPriceCounts.get(item.unitPrice) ?? 0) + 1);
      }
    }
    // Build list of OCR prices not yet consumed, respecting duplicate prices
    const remainingCounts = new Map(usedPriceCounts);
    const unusedOCR: number[] = [];
    for (const p of priceList) {
      const used = remainingCounts.get(p) ?? 0;
      if (used > 0) {
        remainingCounts.set(p, used - 1);
      } else {
        unusedOCR.push(p);
      }
    }
    let ui = 0;
    for (const item of missing) {
      if (ui < unusedOCR.length) {
        item.unitPrice = unusedOCR[ui++];
      }
    }
    logger?.debug(
      {
        mode: "llm-gap-fill",
        llmHasPrices,
        gapFilledCount: ui,
        finalPricedCount: items.filter(i => i.unitPrice && i.unitPrice > 0).length,
        itemCount: items.length,
      },
      "Using LLM prices with OCR gap fill"
    );
    return;
  }

  const pLen = priceList.length;
  const iLen = items.length;
  const ratio = iLen > 0 ? pLen / iLen : 0;

  if (ratio >= 0.6 && ratio <= 1.4) {
    let pi = 0;
    for (let ii = 0; ii < iLen && pi < pLen; ii++) {
      items[ii].unitPrice = priceList[pi];
      const total = totalList[pi];
      if (total > 0 && Math.abs(total - priceList[pi]) > 0.05 && priceList[pi] > 0) {
        items[ii].quantity = Math.round(total / priceList[pi]);
      }
      pi++;
    }
    logger?.debug(
      { mode: "sequential", assignedPrices: pi, productCount: iLen },
      "Sequential price assignment applied"
    );
    return;
  }

  logger?.debug(
    { mode: "fallback", productCount: iLen, priceCount: pLen },
    "Price count mismatch, keeping LLM prices"
  );
}

function extractOCRNumbers(line: string): number[] {
  const results: number[] = [];
  const pattern = /(\d+)[.,](\d{2})(?!\d)|\.(\d{2})(?!\d)/g;
  let match;
  while ((match = pattern.exec(line)) !== null) {
    let val: number;
    if (match[3] !== undefined) {
      val = parseFloat(`0.${match[3]}`);
    } else {
      val = parseFloat(`${match[1]}.${match[2]}`);
    }
    if (val > 0 && val < 500) {
      results.push(val);
    }
  }
  return results;
}

function extractPriceAndTotalColumns(lines: string[], logger?: LoggerLike): { prices: number[]; totals: number[] } {
  const candidates: { line: string; numbers: number[]; hasPreis: boolean; hasTotal: boolean }[] = [];

  for (const line of lines) {
    const numbers = extractOCRNumbers(line);
    if (numbers.length < 5) continue;

    candidates.push({
      line,
      numbers,
      hasPreis: /pre[i1]s/i.test(line),
      hasTotal: /total/i.test(line),
    });
  }

  if (candidates.length === 0) return { prices: [], totals: [] };

  candidates.sort((a, b) => b.numbers.length - a.numbers.length);

  let preisCandidate = candidates.find(c => c.hasPreis);
  let totalCandidate = candidates.find(c => c.hasTotal && c !== preisCandidate);

  if (!preisCandidate && !totalCandidate) {
    preisCandidate = candidates[0];
    totalCandidate = candidates.length > 1 ? candidates[1] : undefined;
  } else if (!preisCandidate) {
    preisCandidate = totalCandidate;
    totalCandidate = candidates.find(c => c !== preisCandidate);
  }

  if (!preisCandidate) return { prices: [], totals: [] };

  let prices = stripTrailingSum(preisCandidate.numbers);

  if (prices.length < 5) {
    logger?.debug({ extractedPrices: prices.length }, "Too few prices after extraction");
    return { prices: [], totals: [] };
  }

  if (totalCandidate) {
    let totals = stripTrailingSum(totalCandidate.numbers);

    if (totals.length >= prices.length * 0.7) {
      const minLen = Math.min(prices.length, totals.length);
      prices = prices.slice(0, minLen);
      totals = totals.slice(0, minLen);

      let priceBigger = 0;
      let totalBigger = 0;
      for (let i = 0; i < minLen; i++) {
        if (totals[i] > prices[i] + 0.05) totalBigger++;
        if (prices[i] > totals[i] + 0.05) priceBigger++;
      }
      if (priceBigger > totalBigger) {
        [prices, totals] = [totals, prices];
      }

      logger?.debug({ prices: prices.length, totals: totals.length }, "Using dual-column mode");
      return { prices, totals };
    }
  }

  logger?.debug({ prices: prices.length }, "Using single-column mode");
  return { prices, totals: prices.map(() => 0) };
}

function stripTrailingSum(numbers: number[]): number[] {
  if (numbers.length < 3) return numbers;

  for (let cut = numbers.length; cut >= 3; cut--) {
    const slice = numbers.slice(0, cut);
    const last = slice[slice.length - 1];
    const sumRest = slice.slice(0, -1).reduce((a, b) => a + b, 0);
    if (Math.abs(last - sumRest) < 0.05) {
      return slice.slice(0, -1);
    }
  }

  return numbers;
}

