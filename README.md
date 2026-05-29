# Mersal Memo

A lightweight, floating markdown note-taking app for macOS. Lives in a corner of your screen as a small bubble — click to expand, write fast, collapse and get back to work.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

---

## Features

**Markdown editor with live highlighting**
- Bold, italic, strikethrough, inline code, code blocks
- Headings (H1–H3), blockquotes, lists, checklists
- Clickable checkboxes — click to toggle completion
- Inline links with a hover-activated link editor
- Image rendering from file paths

**Bubble mode**
- Collapses to a small floating circle in any corner of your screen
- Stays out of the way until you need it
- Configurable position: top-left, top-right, bottom-left, bottom-right

**Note management**
- Unlimited notes, saved locally as JSON
- Search across all notes by title and content
- Import and export individual notes as `.md` files
- Auto-saves as you type

**Window controls**
- Pin window on top of other apps
- Adjustable opacity (30–100%)

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+N` | New note |
| `Cmd+[` | Previous note |
| `Cmd+]` | Next note |
| `Cmd+F` | Find in note |
| `Cmd+Shift+F` | Search all notes |
| `Cmd+Shift+P` | Pin / unpin window |
| `Tab` | Indent (2 spaces) |
| `Shift+Tab` | Unindent |

---

## Building & Running

Requires Xcode or the Swift toolchain on macOS 13+.

```bash
# Build and launch
./run.sh
```

Or build manually:

```bash
swift build
.build/debug/MersalMemo
```

---

## Data Storage

Notes are stored at:
```
~/Library/Application Support/MersalMemo/notes.json
```

---

## License

MIT — see [LICENSE](LICENSE).
