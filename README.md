# NowRSS

AI-powered RSS reader for Linux with Feedbin sync.

[![Build Linux](https://github.com/cragnet/NowRSS/actions/workflows/build-linux.yml/badge.svg)](https://github.com/cragnet/NowRSS/actions/workflows/build-linux.yml)

## Features

- **Feedbin Integration** — Sync feeds, articles, and starred items
- **AI-Powered Summaries** — Generate article summaries using Ollama Cloud, OpenAI, or any OpenAI-compatible provider
- **Smart Organization** — Folders, unread/read filters, favorites
- **Duplicate Detection** — Automatically mark duplicate articles as read
- **Keyword Filtering** — Auto-mark articles containing specific keywords
- **Three-View Reading** — Text only, Text + Images, or Original WebView
- **Progress Bars** — Visual feedback during all loading operations
- **Settings Export/Import** — Backup and restore your configuration

## Installation

### Download Pre-built Binary

Download the latest release from the [Releases page](https://github.com/cragnet/NowRSS/releases).

```bash
tar -xzf nowrss-linux-x64.tar.gz
cd bundle
./nowrss
```

### Build from Source

```bash
git clone https://github.com/cragnet/NowRSS.git
cd NowRSS
flutter pub get
flutter build linux --release
```

## Configuration

### Feedbin

Set your Feedbin credentials in Settings.

### AI Provider

NowRSS supports multiple AI providers:

| Provider | Base URL |
|----------|----------|
| Ollama Cloud | `https://api.ollama.com/v1` |
| Ollama Local | `http://localhost:11434` |
| OpenAI | `https://api.openai.com/v1` |
| Custom | Your own endpoint |

See [AI_SETUP.md](docs/AI_SETUP.md) for detailed configuration.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `J` / `↓` | Next article |
| `K` / `↑` | Previous article |
| `M` | Mark as read/unread |
| `S` | Star/unstar |
| `O` | Open in browser |
| `R` | Refresh feeds |
| `?` | Show shortcuts |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License — see [LICENSE](LICENSE) file.
