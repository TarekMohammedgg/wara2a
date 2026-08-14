# wara2a

Arabic-first Flutter app for capturing invoices, extracting fields via OpenRouter Gemini, reviewing drafts, storing invoices locally in ObjectBox, and searching with OpenRouter `text-embedding-3-small` embeddings.

## Setup

```powershell
flutter pub get
```

Add an OpenRouter API key in Settings, or pass:

```powershell
flutter run --dart-define=OPENROUTER_API_KEY=sk-or-...
```

See [docs/development.md](docs/development.md) for analyze/test gates.
