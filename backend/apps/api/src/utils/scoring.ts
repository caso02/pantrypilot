/**
 * Jaccard similarity between two token sets: |A∩B| / |A∪B|
 */
export function jaccardSimilarity(a: string[], b: string[]): number {
  const setA = new Set(a);
  const setB = new Set(b);
  let intersection = 0;
  for (const token of setA) {
    if (setB.has(token)) intersection++;
  }
  const union = setA.size + setB.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

/**
 * Counts how many tokens in `query` are a prefix of any token in `candidate`.
 * Returns a ratio (0..1).
 */
export function prefixMatchRatio(
  queryTokens: string[],
  candidateTokens: string[]
): number {
  if (queryTokens.length === 0) return 0;
  let matches = 0;
  for (const qt of queryTokens) {
    if (candidateTokens.some((ct) => ct.startsWith(qt))) {
      matches++;
    }
  }
  return matches / queryTokens.length;
}

/**
 * Levenshtein edit distance (lightweight, no dependency).
 */
export function levenshtein(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;

  const dp: number[] = Array.from({ length: n + 1 }, (_, i) => i);

  for (let i = 1; i <= m; i++) {
    let prev = i - 1;
    dp[0] = i;
    for (let j = 1; j <= n; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      const temp = dp[j];
      dp[j] = Math.min(dp[j] + 1, dp[j - 1] + 1, prev + cost);
      prev = temp;
    }
  }

  return dp[n];
}

/**
 * Normalized Levenshtein similarity (0..1, 1 = identical).
 */
export function levenshteinSimilarity(a: string, b: string): number {
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 1;
  return 1 - levenshtein(a, b) / maxLen;
}

export interface ScoredCandidate<T> {
  item: T;
  score: number;
}

/**
 * Combined scoring: 50% Jaccard, 30% prefix match, 20% Levenshtein on joined strings.
 */
export function combinedScore(
  queryTokens: string[],
  candidateTokens: string[]
): number {
  const jaccard = jaccardSimilarity(queryTokens, candidateTokens);
  const prefix = prefixMatchRatio(queryTokens, candidateTokens);
  const lev = levenshteinSimilarity(
    queryTokens.join(" "),
    candidateTokens.join(" ")
  );
  return jaccard * 0.5 + prefix * 0.3 + lev * 0.2;
}
