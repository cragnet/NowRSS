# Changelog

All notable changes to NowRSS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project scaffold
- Three-pane UI layout (Feed Tree | Article List | Reading Pane)
- Feedbin API integration
- AI provider support (Ollama Cloud, OpenAI, OpenAI-compatible)
- Article summarization and translation
- Duplicate detection with fuzzy matching
- Keyword filtering with auto-mark-as-read
- Settings export/import with optional API key inclusion
- Progress bars for all loading operations
- GitHub Actions CI/CD for automated Linux builds

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
