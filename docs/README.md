# OpenType Documentation

OpenType is a global AI voice input tool for macOS. Tap a shortcut, speak in any text field, and the cleaned-up text lands at the cursor. These documents cover installing and using the app, how it is built, and how to work on it.

> The `docs/` folder also hosts the project's static website (`index.html`, `styles.css`, `main.js`, `i18n.js`, `assets/`). The Markdown files listed here sit alongside it and are not part of the site.

## For users

| Document | What it covers |
| --- | --- |
| [Getting Started](getting-started.md) | Installing, first launch, granting permissions, configuring speech recognition and the AI service |
| [User Guide](user-guide.md) | The three modes, shortcuts, the overlay, the main window, history, menu bar, and every settings tab |
| [Dictionary](dictionary.md) | Built-in packs, custom entries, auto-replace, and how dictionary words reach the model |
| [Troubleshooting](troubleshooting.md) | Shortcuts that do nothing, permissions that will not stick, insertion and service errors |
| [Privacy and Security](privacy-and-security.md) | Exactly what leaves your Mac, what is stored locally, and where |

## For contributors

| Document | What it covers |
| --- | --- |
| [Architecture](architecture.md) | Components, the session pipeline and state machine, concurrency rules, error handling |
| [Services Reference](services-reference.md) | Speech recognition providers, LLM protocol adapters, prompts, Say It for Me web search |
| [Development](development.md) | Building, testing, project layout, code conventions, signing and packaging |
| [Releasing](releasing.md) | How a release is cut, and how the in-app updater consumes it |

## Related files

- [`README.md`](../README.md): project overview (also in [简体中文](../README.zh-Hans.md), [繁體中文](../README.zh-Hant.md), [日本語](../README.ja.md), [한국어](../README.ko.md)).
- [`OpenType PRD.md`](../OpenType%20PRD.md): the original product requirements (in Chinese).
- [`release-notes/`](../release-notes): per-version release notes in five languages.
- [`AGENTS.md`](../AGENTS.md): working rules for contributors and coding agents (commits, packaging, releases).

## Conventions used in these docs

- UI names follow the app's English strings, for example **Say It for Me** and **Settings → Speech Recognition**.
- `⌃` is Control, `⌥` is Option, `⇧` is Shift, `⌘` is Command.
- Paths beginning with `~` are in the current user's home folder.
- Source references such as `OpenType/Core/DictationSessionCoordinator.swift` are relative to the repository root.
