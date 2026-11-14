# Dictionary

Speech recognition often garbles technical terms: "OpenAI" becomes "open a i", "Kubernetes" turns into something unrecognizable, `C++` loses its pluses. The dictionary fixes this in two complementary ways, and it works in every mode.

## How it helps

When a session finishes recognizing, the text passes through the dictionary before the model sees it:

1. **Auto-replace (deterministic).** For entries with **Auto-Replace** on, the term and each of its aliases are replaced with the correct spelling directly in the recognized text. This happens before the AI step, so it also works in **Raw** mode and when AI processing is off.
2. **Hints for the model.** If the recognized text mentions any dictionary word, the model's prompt gets an extra section listing those words with their correct spelling and common misrecognitions. The model is told to use that spelling only when the speech really refers to the word, and not to force unrelated words into it. When no dictionary word is mentioned the prompt is unchanged.

The hint section applies to dictation, voice translation and Say It for Me alike.

## Built-in packs

Packs are bundled with the app and can be switched on or off individually in the **Dictionary** tab.

| Pack | Contents |
| --- | --- |
| General coding | Common programming terms |
| Git | Git commands and concepts |
| Swift | Keywords and common functions |
| Python | Keywords and common functions |
| JavaScript / TypeScript | Keywords and common functions |
| Shell | Keywords and common commands |
| SQL | Keywords and common functions |
| HTML / CSS | Tags, properties and common terms |
| AI concepts | Agent Harness, MCP, RAG and similar |
| AI vendors and products | OpenAI, Anthropic, DeepSeek and similar |

Built-in entries default to Auto-Replace **off**, because plain words such as `list` or `set` would be wrong to rewrite everywhere. They still feed the model hints.

A master switch turns the whole dictionary off.

## Custom entries

Add your own words in the **Dictionary** tab:

- **Term**: the correct spelling, for example `OpenAI` or `Kubernetes`.
- **Aliases**: how it tends to be misheard or misspelled, separated by commas (`,`, `，`, `、`), semicolons or new lines. Examples: `open ai`, `k8s`.
- **Auto-Replace**: on by default for custom entries.

Custom entries take precedence over built-in packs when both define the same term. Duplicate aliases (ignoring case) and aliases identical to the term are dropped automatically.

## Matching rules

Understanding these helps you write good aliases.

**Hints (which entries count as mentioned)**

- ASCII spellings are compared after "squashing" (lowercase, keeping only letters, digits, `+` and `#`). A run of up to five consecutive transcript words is also squashed, so "open ai", "open-ai" and "OpenAI" all match `openai`, and "c plus plus"-style runs are covered.
- Non-ASCII spellings (for example Chinese misrecognitions) are matched as substrings of the squashed transcript.
- Spellings shorter than two characters after squashing are ignored.
- At most 40 hints are sent per request, in dictionary order.

**Auto-replace**

- Matching is case-insensitive. Spaces, hyphens and underscores inside a spelling match any mix of those (so `open ai` also finds `OpenAI` and `open-ai`).
- Pure ASCII spellings must stand alone: they do not match inside a longer word (so `git` will not rewrite `digit`).
- Non-ASCII spellings are matched as plain text.
- All matches are found on the original text. Where matches overlap, the longest wins, so a replacement is never rewritten again by another rule.

## Storage

Dictionary settings (master switch, disabled packs) and custom entries are saved as one JSON file at `~/Library/Application Support/OpenType/dictionary.json`. Built-in packs ship inside the app as `dict-<id>.json` resources and are never written to disk by the app.

## Not yet supported

Import and export of the dictionary, and biasing the speech recognizer itself with dictionary words, are on the roadmap.
