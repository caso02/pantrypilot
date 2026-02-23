const UMLAUT_MAP: Record<string, string> = {
  ä: "ae",
  ö: "oe",
  ü: "ue",
  Ä: "Ae",
  Ö: "Oe",
  Ü: "Ue",
  ß: "ss",
};

export function expandUmlauts(text: string): string {
  return text.replace(/[äöüÄÖÜß]/g, (ch) => UMLAUT_MAP[ch] ?? ch);
}

/**
 * Strips prices (e.g. "1.60", "CHF 3.95"), pure numeric tokens,
 * weight/unit suffixes already captured elsewhere, then uppercases + trims.
 */
export function normalizeRawKey(rawText: string): string {
  let key = rawText.toUpperCase().trim();

  // Remove CHF / EUR price patterns like "CHF 1.60" or "1.60 CHF"
  key = key.replace(/\b(CHF|EUR)\s*\d+[.,]?\d*/gi, "");
  key = key.replace(/\d+[.,]\d+\s*(CHF|EUR)?\b/g, "");

  // Remove number+unit combos like "1L", "500G", "2X", "150G", "3.5%"
  key = key.replace(/\b\d+(\.\d+)?(%|[A-Z]{1,3})?/g, "");
  // Remove orphaned % signs
  key = key.replace(/%/g, "");

  // Remove excess whitespace
  key = key.replace(/\s+/g, " ").trim();

  return key;
}

/**
 * Tokenizes text for keyword matching.
 * Lowercases, expands umlauts, splits on non-alphanumeric, removes short/stop tokens.
 */
export function tokenize(text: string): string[] {
  const STOP_WORDS = new Set([
    "und", "oder", "der", "die", "das", "ein", "eine", "mit", "aus",
    "von", "für", "bei", "im", "am", "zum", "zur", "den", "dem",
    "des", "auf", "in", "an", "chf", "eur", "stk", "stück",
  ]);

  const normalized = expandUmlauts(text.toLowerCase());
  const parts = normalized.split(/[^a-z0-9äöüàéèêâîôûç]+/i).filter(Boolean);

  return parts
    .filter((t) => t.length >= 2)
    .filter((t) => !STOP_WORDS.has(t))
    .filter((t) => !/^\d+$/.test(t));
}

/**
 * Builds a canonical display name from a raw product name.
 * Title-cases words, preserves known brand patterns.
 */
export function buildCanonicalName(name: string): string {
  const PRESERVED = ["M-Classic", "M-Budget", "IP-SUISSE", "Bio", "Aha!", "V-Love"];

  const words = name.trim().split(/\s+/);
  return words
    .map((w) => {
      for (const brand of PRESERVED) {
        if (brand.toLowerCase() === w.toLowerCase()) return brand;
      }
      if (w.length <= 3 && w === w.toUpperCase()) return w;
      if (w.length <= 2) return w.toUpperCase();
      if (w.includes("-")) {
        return w
          .split("-")
          .map((p) =>
            p.length <= 1
              ? p.toUpperCase()
              : p[0].toUpperCase() + p.slice(1).toLowerCase()
          )
          .join("-");
      }
      return w[0].toUpperCase() + w.slice(1).toLowerCase();
    })
    .join(" ");
}
