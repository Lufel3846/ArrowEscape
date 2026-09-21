# Arrow Escape

Unwind and challenge your brain with Arrow Escape, a clean, minimalist puzzle game built purely for the love of play.

[![AI-DECLARATION: pair](https://img.shields.io/badge/🤖%20AI--DECLARATION-pair-fee2e2?labelColor=fee2e2)](AI-DECLARATION.md)

---

## 🙏 Credits

This project is a **fork of [Arrow Escape](https://github.com/sidhant947/ArrowEscape)**, originally created and developed by **[sidhant947](https://github.com/sidhant947)**. All credit for the original game concept, core puzzle mechanics, procedural level generator, and initial architecture goes to them.

This fork is maintained by [Lufel3846](https://github.com/Lufel3846) and builds on top of the original work with new features and improvements (see [What's New in This Fork](#-whats-new-in-this-fork) below).

If you enjoy the game, please consider giving a star to **both** repositories:
- ⭐ [Original by sidhant947](https://github.com/sidhant947/ArrowEscape)
- ⭐ [This fork](https://github.com/Lufel3846/ArrowEscape)

Support the original developer: [ko-fi.com/sidhant947](https://ko-fi.com/sidhant947)

---

## 🌟 Key Features

- **Infinite Levels**: Procedurally generated puzzles ensure you never run out of challenges.
- **100% Offline Play**: Play anywhere — on a plane, underground, or off the grid — without needing an internet connection.
- **Zero Ads and Trackers**: No popup interruptions, banner ads, or background tracking scripts. Just pure gameplay.
- **Complete Privacy**: No account needed, no data collected, and no unnecessary permissions requested.
- **Minimalist Design**: Clean visuals and crisp effects designed to help you focus and relax.

Whether you have two minutes to spare or want to zone out for an hour, Arrow Escape is the ultimate clean, privacy-respecting puzzle fix.

## 🧩 Game Modes

| Mode | Description |
|---|---|
| **Classic** | 500 handcrafted-feeling levels with progression, stars, boss and god levels. Timed variants on advanced boss/god levels. |
| **Zen** | No lives, no timers. Just relax and solve. |
| **Time Attack** | 60 seconds on the clock — each solved puzzle adds +15s. How far can you go? |
| **Daily Challenge** | A new puzzle every day, the same for everyone worldwide. Build your streak! |
| **Random** | Instant puzzle from 5 difficulty tiers (Easy → Expert). |
| **Custom Levels** | Create and share your own puzzles with the built-in editor. |

## ✨ Features in This Fork

- **Undo** — one undo per level to take back a mistake (restores lives, dots and combos).
- **Watch Solution** — after completing a level, watch the solver replay the correct order on the board.
- **Level Editor** — build custom puzzles on a grid (5×5 to 10×10), validate solvability automatically, and share them as compact `ARW-...` codes. Paste a friend's code to play their puzzle.
- **Daily Challenge & Streaks** — deterministic daily puzzle derived from the date, with streak tracking.
- **Achievements** — 12 achievements covering progression, stars, combos and daily streaks, with in-game unlock banners.
- **Statistics** — levels completed, total stars, perfect levels, best combo and more, persisted locally.
- **Deadlock detection** — the game now tells you when no moves remain and offers a restart.

## 🎨 Themes & Custom Skins

Arrow Escape includes a theme selection system with custom skins. If you use it, support by giving a star to the repos.

* **Unlock Code**: `THANKYOU` (Enter this code to unlock all themes & custom skins instantly).

---

## 🛠️ Tech Stack

- **Flutter** + **Flame** (2D game engine) — Dart
- **Hive** for local persistence (progress, stats, level cache)
- **flutter_riverpod** for state management
- Procedural, seed-based level generation with a built-in solver that guarantees every level is solvable

## 🚀 Getting Started

```bash
# Clone your fork of the repo
git clone https://github.com/Lufel3846/ArrowEscape.git
cd ArrowEscape

# Install dependencies
flutter pub get

# Run the app
flutter run
```

Requires a working [Flutter SDK](https://docs.flutter.dev/get-started/install). Targets Android and Web.

## 🧪 Tests & CI

```bash
flutter analyze   # static analysis
flutter test      # unit + widget tests (43 tests)
```

A GitHub Actions workflow (`.github/workflows/ci.yml`) runs analysis and tests on every push and pull request.

---

## License

GPL v3 — inherited from the original project. See [LICENSE](LICENSE).
