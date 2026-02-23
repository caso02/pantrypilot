import { describe, it, expect } from "vitest";
import {
  jaccardSimilarity,
  prefixMatchRatio,
  levenshtein,
  levenshteinSimilarity,
  combinedScore,
} from "./scoring.js";

describe("jaccardSimilarity", () => {
  it("returns 1 for identical sets", () => {
    expect(jaccardSimilarity(["a", "b"], ["a", "b"])).toBe(1);
  });

  it("returns 0 for disjoint sets", () => {
    expect(jaccardSimilarity(["a"], ["b"])).toBe(0);
  });

  it("returns correct ratio for partial overlap", () => {
    const score = jaccardSimilarity(["a", "b", "c"], ["b", "c", "d"]);
    expect(score).toBeCloseTo(0.5); // 2 / 4
  });

  it("handles empty sets", () => {
    expect(jaccardSimilarity([], [])).toBe(0);
    expect(jaccardSimilarity(["a"], [])).toBe(0);
  });
});

describe("prefixMatchRatio", () => {
  it("returns 1 when all query tokens are prefixes", () => {
    expect(prefixMatchRatio(["mil", "vol"], ["milch", "vollmilch"])).toBe(1);
  });

  it("returns 0 when no query tokens match", () => {
    expect(prefixMatchRatio(["xyz"], ["milch"])).toBe(0);
  });

  it("returns 0.5 for partial matches", () => {
    expect(prefixMatchRatio(["mil", "xyz"], ["milch"])).toBe(0.5);
  });

  it("handles empty query", () => {
    expect(prefixMatchRatio([], ["milch"])).toBe(0);
  });
});

describe("levenshtein", () => {
  it("returns 0 for identical strings", () => {
    expect(levenshtein("milch", "milch")).toBe(0);
  });

  it("returns correct edit distance", () => {
    expect(levenshtein("kitten", "sitting")).toBe(3);
  });

  it("handles empty strings", () => {
    expect(levenshtein("", "abc")).toBe(3);
    expect(levenshtein("abc", "")).toBe(3);
  });
});

describe("levenshteinSimilarity", () => {
  it("returns 1 for identical strings", () => {
    expect(levenshteinSimilarity("milch", "milch")).toBe(1);
  });

  it("returns 0 for completely different equal-length strings", () => {
    expect(levenshteinSimilarity("abc", "xyz")).toBe(0);
  });

  it("returns value between 0 and 1", () => {
    const sim = levenshteinSimilarity("milch", "mileh");
    expect(sim).toBeGreaterThan(0);
    expect(sim).toBeLessThan(1);
  });
});

describe("combinedScore", () => {
  it("returns high score for identical token sets", () => {
    const score = combinedScore(["bio", "milch"], ["bio", "milch"]);
    expect(score).toBeGreaterThan(0.9);
  });

  it("returns moderate score for partial overlap", () => {
    const score = combinedScore(["milch"], ["bio", "milch", "vollmilch"]);
    expect(score).toBeGreaterThan(0.2);
    expect(score).toBeLessThan(0.9);
  });

  it("returns low score for unrelated tokens", () => {
    const score = combinedScore(["poulet"], ["milch", "bio"]);
    expect(score).toBeLessThan(0.3);
  });
});
