import { describe, it, expect } from "vitest";
import {
  normalizeRawKey,
  tokenize,
  buildCanonicalName,
  expandUmlauts,
} from "./normalize.js";

describe("normalizeRawKey", () => {
  it("removes CHF prices", () => {
    expect(normalizeRawKey("M-CLASSIC MILCH 1L CHF 1.60")).toBe(
      "M-CLASSIC MILCH"
    );
  });

  it("removes standalone numbers and price-like patterns", () => {
    expect(normalizeRawKey("BIO JOGHURT 2x 150g 3.95")).toBe(
      "BIO JOGHURT"
    );
  });

  it("trims and collapses whitespace", () => {
    expect(normalizeRawKey("  VOLLMILCH   3.5%  ")).toBe("VOLLMILCH");
  });

  it("handles EUR prices", () => {
    expect(normalizeRawKey("BROT EUR 2.50")).toBe("BROT");
  });

  it("uppercases the result", () => {
    expect(normalizeRawKey("Milch")).toBe("MILCH");
  });
});

describe("tokenize", () => {
  it("lowercases and splits", () => {
    const tokens = tokenize("Bio Vollmilch 3.5%");
    expect(tokens).toContain("bio");
    expect(tokens).toContain("vollmilch");
  });

  it("filters stop words", () => {
    const tokens = tokenize("Käse mit Kräutern");
    expect(tokens).not.toContain("mit");
    expect(tokens).toContain("kaese");
    expect(tokens).toContain("kraeutern");
  });

  it("expands umlauts", () => {
    const tokens = tokenize("Müesli Nüsse Körner");
    expect(tokens).toContain("mueesli");
    expect(tokens).toContain("nuesse");
    expect(tokens).toContain("koerner");
  });

  it("filters pure numeric tokens", () => {
    const tokens = tokenize("500 Gramm Mehl");
    expect(tokens).not.toContain("500");
    expect(tokens).toContain("gramm");
    expect(tokens).toContain("mehl");
  });

  it("filters short tokens (<2 chars)", () => {
    const tokens = tokenize("A B Bio C");
    expect(tokens).toContain("bio");
    expect(tokens).not.toContain("a");
    expect(tokens).not.toContain("b");
  });
});

describe("buildCanonicalName", () => {
  it("title-cases words", () => {
    expect(buildCanonicalName("BIO VOLLMILCH")).toBe("Bio Vollmilch");
  });

  it("preserves M-Classic brand", () => {
    expect(buildCanonicalName("M-CLASSIC MILCH")).toBe("M-Classic Milch");
  });

  it("preserves M-Budget brand", () => {
    expect(buildCanonicalName("m-budget pasta")).toBe("M-Budget Pasta");
  });

  it("handles hyphenated words", () => {
    expect(buildCanonicalName("HOCH-PASTEURISIERT")).toBe(
      "Hoch-Pasteurisiert"
    );
  });

  it("keeps short words uppercase", () => {
    expect(buildCanonicalName("BIO UHT MILCH")).toBe("Bio UHT Milch");
  });
});

describe("expandUmlauts", () => {
  it("replaces German umlauts", () => {
    expect(expandUmlauts("Müller Käse Bröt")).toBe("Mueller Kaese Broet");
  });

  it("handles uppercase umlauts", () => {
    // Ü→Ue, Ö→Oe, Ä→Ae: "ÜBER" → "UeBER", "ÖLKÄNNCHEN" → "OeLKAeNNCHEN"
    expect(expandUmlauts("ÜBER ÖLKÄNNCHEN")).toBe("UeBER OeLKAeNNCHEN");
  });

  it("replaces ß", () => {
    expect(expandUmlauts("Straße")).toBe("Strasse");
  });
});
