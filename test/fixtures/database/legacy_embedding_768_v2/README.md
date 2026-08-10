# Legacy embedding store fixture

`data.mdb` is a real ObjectBox store generated from Wara2a schema v2 before
the embedding index changed from 768 to 384 dimensions. It contains:

- one invoice with a normalized 768-dimensional EmbeddingGemma vector;
- one related invoice-item row; and
- database, search-text, and embedding metadata set to schema version 2.

The fixture is immutable. Migration tests must copy it to a temporary
directory before opening it because ObjectBox upgrades stores in place.

- Legacy vector property UID: `3475944700035130751`
- Legacy HNSW index UID: `5674699518843013707`
- SHA-256 (`data.mdb`):
  `741f43019369c16796d75c4a106fb89bdf020ef2443872b2d8e26883b06eed31`
