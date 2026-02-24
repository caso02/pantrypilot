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
Extrahiere ALLE Produkte aus OCR-Daten und gib sie in EXAKT DER REIHENFOLGE zurück wie sie auf dem Kassenzettel stehen.

OCR-SPALTENFORMAT:
Die OCR liest Kassenzettel oft spaltenweise: eine Zeile enthält alle Produktnamen hintereinander, eine andere alle Preise. Produktnamen können über mehrere OCR-Zeilen verteilt sein.

PRODUKTE TRENNEN:
- Jeder Kassenzettel-Eintrag ist ein EINZELNER Artikel ("Bio Birnen Williams" ≠ "Zwiebeln rot")
- Migros-Kürzel: M-CL/MClass = M-Classic, M-BU/MBud = M-Budget
- Abkürzungen: Thony→Thomy, Tortell.→Tortellini, Ric.→Ricotta, Atl.→Atlantischer, VALFL→Valflora
- Schne12kase/Schnelzkäse → Schmelzkäse
- "Chiefs Pudding Choco" und "Chiefs Pudding Stracci" sind ZWEI Produkte
- KEIN Produkt: einzelne Markenname ohne Produktname ("M-Budget" allein, "M-Classic" allein), einzelne Wörter wie "Satz", "Bar", Barcodenummern

MENGEN (quantity):
- Standard = 1
- "2 Produkt", "2x Produkt", "2 x Produkt" → quantity: 2
- Folgezeile "2 Stk", "2 St", "2 à", "2 x 1.50" direkt nach einem Produkt → quantity: 2 für dieses Produkt
- "6er Pack", "4-Pack", "12er Karton", "0.5 kg" → quantity: 1 (Verpackungsgrösse, nicht Stückzahl)
- Gleiches Produkt 2× auf Kassenzettel → 2 separate Einträge mit quantity: 1 (NICHT ein Eintrag mit quantity: 2)

REIHENFOLGE (KRITISCH):
- Nummeriere mit "position" (1, 2, 3, ...) in der EXAKTEN Reihenfolge der OCR-Zeilen
- Produkte aus Zeile 1 kommen vor Produkten aus Zeile 2, usw.
- Innerhalb einer Zeile: Reihenfolge von links nach rechts im Text

Ignorieren: Totale, Zahlungen, MwSt, Barcodes, Header, Footer, "Sie sparen", Cumulus, KNr, "Total CHF", "Bar CHF", "Zurück", "Zwischentotal"

KEIN Halluzinieren: Extrahiere NUR Produkte die explizit im OCR-Text stehen. Erfinde KEINE Produkte die nicht vorkommen.

Antwort: NUR ein JSON-Array, keine Erklärungen, kein Markdown.`;

const LLM_REQUEST_TIMEOUT_MS = 60_000;

async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs = LLM_REQUEST_TIMEOUT_MS): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

function buildUserPrompt(lines: string[], priceList: number[], totalList: number[]): string {
  const numbered = lines.map((l, i) => `Zeile ${i + 1}: "${l}"`).join("\n");

  const estimatedCount = estimateProductCount(lines);

  let priceContext = "";
  if (priceList.length > 0) {
    const priceRows = priceList.map((p, i) => {
      const total = totalList[i] ?? 0;
      let hint = "";
      if (total > p + 0.09 && p > 0) {
        const ratio = total / p;
        const rounded = Math.round(ratio);
        if (Math.abs(ratio - rounded) < 0.05 && rounded >= 2 && rounded <= 20) {
          hint = ` → Total: ${total.toFixed(2)} CHF, MENGE: ${rounded}! (${p.toFixed(2)} × ${rounded} = ${total.toFixed(2)})`;
        } else {
          // Total doesn't match a clean multiple — OCR likely dropped a digit from unit price
          hint = ` → Total: ${total.toFixed(2)} CHF ⚠ (Preis evtl. falsch erkannt, richtiger Preis = Total ÷ Menge)`;
        }
      }
      return `  ${i + 1}. ${p.toFixed(2)} CHF${hint}`;
    });
    priceContext = `\nAus der Preis-Spalte wurden ${priceList.length} Einheitspreise extrahiert (gleiche Reihenfolge wie Produkte):
${priceRows.join("\n")}
Wenn "MENGE: N" steht, hat der Kunde N Stück dieses Produkts gekauft → setze quantity: N.
Die OCR kann Preise falsch lesen. Ordne die Preise den Produkten in der gleichen Reihenfolge zu.
Falls es MEHR Produkte als Preise gibt: schätze fehlende Preise basierend auf typischen Schweizer Supermarkt-Preisen.\n`;
  }
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

Gib ein JSON-Array zurück (Produkte in Kassenzettel-Reihenfolge, position beginnt bei 1):
[{"position":1,"rawText":"OCR-Kürzel","productName":"Voller Name","brand":"Marke oder null","quantity":1,"unit":"Stk","unitPrice":3.50,"category":"Kategorie","confidence":"high|medium|low"}]`;
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
  const res = await fetchWithTimeout("https://api.openai.com/v1/chat/completions", {
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
      max_tokens: 2048,
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
  const res = await fetchWithTimeout("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: 2048,
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
  const res = await fetchWithTimeout("https://api.perplexity.ai/chat/completions", {
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

  const res = await fetchWithTimeout(url, {
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

  const userPrompt = buildUserPrompt(rawLines, priceList, totalList);
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
    assignPrices(final, priceList, logger);
  }

  // Correct quantities and prices from price/total ratio
  if (priceList.length === final.length && totalList.length === final.length) {
    for (let i = 0; i < final.length; i++) {
      const unitPrice = priceList[i];
      const total = totalList[i] ?? 0;

      // If total ≈ unit_price: definitively qty=1 regardless of what LLM said
      if (total > 0 && unitPrice > 0 && Math.abs(total - unitPrice) < 0.05) {
        if ((final[i].quantity ?? 1) > 1) {
          logger?.debug(
            { productName: final[i].productName, oldQty: final[i].quantity },
            "Quantity forced to 1 (total=unitPrice confirmed single purchase)"
          );
          final[i].quantity = 1;
        }
        continue;
      }

      if (total <= unitPrice + 0.09 || unitPrice <= 0) continue;

      const ratio = total / unitPrice;
      const rounded = Math.round(ratio);

      if (Math.abs(ratio - rounded) < 0.05 && rounded >= 2 && rounded <= 20) {
        // Clean integer ratio → correct quantity
        if (final[i].quantity !== rounded) {
          logger?.debug(
            { productName: final[i].productName, oldQty: final[i].quantity, newQty: rounded, unitPrice, total },
            "Quantity corrected from price/total ratio"
          );
          final[i].quantity = rounded;
        }
      } else {
        // Ratio is not a clean integer — OCR likely dropped a leading digit from the price.
        // Try small quantities and see if total / q gives a clean Swiss price (multiple of 0.05).
        for (let q = 2; q <= 6; q++) {
          const corrected = total / q;
          const isClean = Math.abs(Math.round(corrected * 20) - corrected * 20) < 0.01;
          if (!isClean || corrected < 0.50 || corrected > 99) continue;
          // OCR price must be significantly lower (< 30% of corrected → leading digit was dropped)
          if (unitPrice >= corrected * 0.3) continue;
          // Sanity: difference must be at least 0.80 CHF
          if (corrected - unitPrice < 0.80) continue;
          logger?.debug(
            { productName: final[i].productName, ocrPrice: unitPrice, correctedPrice: corrected, qty: q, total },
            "Price corrected (OCR dropped leading digit)"
          );
          final[i].unitPrice = corrected;
          final[i].quantity = q;
          break;
        }
      }
    }
  }

  return final;
}

function assignPrices(
  items: ParsedReceiptLine[],
  priceList: number[],
  logger?: LoggerLike
): void {
  if (items.length === priceList.length) {
    for (let i = 0; i < items.length; i++) {
      items[i].unitPrice = priceList[i];
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

