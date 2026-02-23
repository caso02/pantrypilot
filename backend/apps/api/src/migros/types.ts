export interface MigrosProduct {
  remoteId: string;
  name: string;
  brand?: string;
  ean?: string;
  unitText?: string;
  categoryPath: string[];
  imageUrl?: string;
}

export interface MigrosSearchResult {
  products: MigrosProduct[];
  totalHits: number;
}
