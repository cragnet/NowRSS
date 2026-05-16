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

#### Prerequisites

**Flutter SDK** (Linux desktop enabled):
```bash
# Install Flutter from https://docs.flutter.dev/get-started/install/linux
# Then enable Linux desktop support:
flutter config --enable-linux-desktop
```

**System dependencies** (Ubuntu/Debian):
```bash
sudo apt update
sudo apt install -y \
  libgtk-3-dev \
  libblkid-dev \
  liblzma-dev \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libssl-dev \
  libsecret-1-dev
```

**System dependencies** (Fedora/RHEL):
```bash
sudo dnf install -y \
  gtk3-devel \
  clang \
  cmake \
  ninja-build \
  pkgconfig \
  openssl-devel \
  libsecret-devel
```

#### Build Steps

```bash
# Clone the repository
git clone https://github.com/cragnet/NowRSS.git
cd NowRSS

# Install Flutter dependencies
flutter pub get

# Build release binary
flutter build linux --release

# The binary will be at:
# build/linux/x64/release/bundle/nowrss

# Optional: Copy to stable install directory
mkdir -p ~/NowRSS/dist
cp build/linux/x64/release/bundle/nowrss ~/NowRSS/dist/
cp -r build/linux/x64/release/bundle/lib ~/NowRSS/dist/
```

#### Run the Application

```bash
# From build output
./build/linux/x64/release/bundle/nowrss

# Or from stable install directory
~/NowRSS/dist/nowrss
```

#### Build Troubleshooting

**Error: `libgtk-3-dev` not found**
→ Install system dependencies listed above.

**Error: `databaseFactory` or sqflite warning**
→ This app uses `sqflite_common_ffi` for Linux. The FFI library is auto-initialized.

**Error: Missing `libflutter_linux_gtk.so` at runtime**
→ Ensure the `lib/` directory is next to the `nowrss` binary:
```bash
ls ~/NowRSS/dist/lib/
# Should show libflutter_linux_gtk.so and other .so files
```

**CI/CD:** The project includes `.github/workflows/build-linux.yml` for automated GitHub Actions builds. Note: GitHub's `ubuntu-latest` runner requires the same `libgtk-3-dev` and `clang` packages installed during the workflow.

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

### Architecture Overview

NowRSS is built with Flutter for Linux desktop only:

- **Entry point:** `lib/main.dart` — Initializes sqflite FFI, loads AppState, launches MainScreen
- **State management:** `lib/services/app_state.dart` — Central ChangeNotifier; handles sync, view switching, settings persistence via SharedPreferences
- **Database:** `lib/services/database_service.dart` — SQLite via sqflite_common_ffi; stores feeds, articles, sync queue, statistics
- **File cache:** `lib/services/file_cache_service.dart` — Disk cache for article HTML, original HTML, and AI summaries
- **Feedbin API:** `lib/services/feedbin_api.dart` — REST client for Feedbin; handles pagination, batch requests, read/starred sync
- **AI service:** `lib/services/ai_provider_service.dart` — Generic client for Ollama and OpenAI-compatible APIs
- **UI:** Three-pane layout in `lib/screens/main_screen.dart` — FeedTree | ArticleList | ReadingPane

### Key Design Decisions

- `~/NowRSS/dist/` is used as the stable install directory because `flutter build` deletes/recreates `build/`
- DOM parser (`html` package) replaces regexes for HTML cleaning — handles nested quotes, escaped chars, CDATA correctly
- Sync fetches 180-day read history via `entries.json?since=` + cross-references with unread ID list to mark reads correctly
- `setView()` and `selectFeed()` are `async` and `await` DB queries before `notifyListeners()` to prevent stale pane 2
- No global `databaseFactory` mutation — uses `databaseFactoryFfi.openDatabase()` directly to eliminate sqflite warnings

## License

MIT License — see [LICENSE](LICENSE) file.
