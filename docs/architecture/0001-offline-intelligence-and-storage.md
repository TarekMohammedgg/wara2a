# ADR 0001: Offline intelligence and local storage stack

- Status: accepted
- Date: 2026-08-09

## Context

Wara2a is Arabic-first and must capture, review, persist, and retrieve invoices without sending invoice data to a remote service. The mandatory review screen remains the boundary between an AI-produced draft and persisted user data.

## Decision

- PaddleOCR PP-OCRv5 will be the replaceable, app-owned OCR boundary.
- Qwen2.5-0.5B-Instruct through LiteRT-LM will map OCR evidence to the strict draft schema; it will not receive invoice images.
- EmbeddingGemma will later create 768-dimensional local retrieval vectors.
- ObjectBox 5.3.2 is the single invoice/item/metadata/vector database, including its cosine HNSW index.
- SharedPreferences is limited to non-critical UI preferences.
- Cubits are feature ViewModels; widgets communicate with persistence only through feature repositories.

The native AI packages and models remain deferred until their physical-device spikes. This decision does not claim camera, OCR, extraction, embedding, or semantic-search readiness.

## Consequences

Invoice data remains local, reviewed records can be updated transactionally, and no cloud/auth/database dependency is introduced. ObjectBox model UIDs and generated schema artifacts are migration-critical and stay in version control.
