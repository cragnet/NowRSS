# Changelog

All notable changes to NowRSS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- AI summaries failing for Ollama Cloud providers because the code always used the native `/api/generate` endpoint for any `type == 'ollama'`. Now correctly routes `/v1` base URLs to `/chat/completions` (OpenAI-compatible) and only uses `/api/generate` for local Ollama instances.
- Added HTTP timeouts (60 s single article / 120 s batch) and improved error propagation so AI failures surface the actual HTTP status and body in logs.

## [0.2.1] - 2026-05-16

### Added
- Feed statistics screen — scrollable per-feed cards with 1h/24h/7d/30d article counts, frequency indicator, mini bar charts for daily and hourly patterns
- Feed selection filters pane 2 by current view mode (clicking a feed shows only its unread/read/favorite/all articles)
- `getRecentEntries()` in Feedbin API — paginated fetch of all entries from last N days with authoritative read/starred state
- File-based cache for article HTML, original page HTML, and AI summaries (filesystem under `cache/{html,original,summary}/`)
- Database schema v3 — added `cached_html`/`cached_original_html` columns (subsequently removed in favor of file cache)

### Changed
- Article reader mode now uses DOM parser (`html` package) instead of regexes — correctly handles nested quotes, apostrophes, backslashes, CDATA, malformed HTML
- Zoom now re-flows text within pane bounds via font-size scaling instead of `Transform.scale` (no more content pushed off-screen)
- Original view also uses DOM-based cleanup (scripts/styles stripped, images/links absolutized)
- SQLite initialization uses `databaseFactoryFfi.openDatabase()` directly instead of mutating global `databaseFactory` (eliminates sqflite warning)
- `syncFeeds()` fetches recent entries from Feedbin instead of only unread IDs — "All Read" now populated with articles read on other devices

### Fixed
- Duplicate `_sortOrder` declaration in `app_state.dart` causing build failure
- Missing `sortOrder` getter causing settings screen compile error
- Regex string-literal escape issues in `reading_pane.dart` breaking on Dart raw-string parsing
- `HtmlEscape` missing import for `dart:convert`

## [0.2.0] - 2026-05-16

### Added
- SQLite local database for caching feeds and articles
- Full Feedbin API integration with two-way sync
- Settings screen with Feedbin credentials, AI providers, keyword filters
- AI summarization and translation (Ollama Cloud, OpenAI, compatible APIs)
- Batch "Summarize All Unread" operation with progress
- Keyword filtering — auto-mark articles as read
- Duplicate detection with fuzzy Levenshtein matching
- Settings export/import with optional API key inclusion
- Keyboard shortcuts (M, S, O, J, K)
- Mark all as read with confirmation dialog
- Copy-to-clipboard for AI summaries
- Auto-sync at startup

## [0.1.0] - 2026-05-16

### Added
- Initial Flutter Linux desktop scaffold
- Three-pane UI layout (Feed Tree | Article List | Reading Pane)
- Material 3 design with progress bars
- GitHub Actions CI/CD for automated Linux builds
