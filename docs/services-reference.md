# Services Reference

How OpenType talks to speech recognition and language-model providers. Everything here is client-side; there is no OpenType server.

## Speech recognition

Every provider implements the `ASRService` protocol and emits the same `ASREvent`s (`preview`, `completed`, `failed`, `finished`), so the rest of the pipeline does not care which one is active. Select the provider under **Settings → Speech Recognition**.

All audio is 16-bit PCM, 16 kHz, mono, sent in about 100 ms chunks.

### Alibaba Cloud Bailian: `qwen3-asr-flash-realtime`

- **Transport:** WebSocket, `wss://<workspaceId>.<region>.maas.aliyuncs.com/api-ws/v1/realtime?model=qwen3-asr-flash-realtime`.
- **Regions:** Beijing (`cn-beijing`) and Singapore (`ap-southeast-1`).
- **Auth:** `Authorization: Bearer <key>` in the handshake header only.
- **Flow:**
  1. Connect and send `session.update` (audio format, language, turn detection).
  2. Wait for `session.updated`.
  3. Stream `input_audio_buffer.append` events with base64 audio.
  4. Send `input_audio_buffer.commit` (manual turn detection only), then `session.finish`.
  5. Collect `...transcription.text` snapshots (preview and `stash`) and `...transcription.completed` (final), until `session.finished`.
- **Turn detection:** server VAD by default (threshold `0.0`, silence `400` ms), or manual.
- **Language:** automatic by default, or a fixed language (Mandarin and dialects, Cantonese, English, Japanese, Korean, and many European and Asian languages).
- **Connect timeout:** 10 s.

### Alibaba Cloud Bailian: `qwen-audio-3.1-asr-flash-message`

- **Transport:** WebSocket, `wss://<workspaceId>.<region>.maas.aliyuncs.com/api-ws/v1/inference`, using the DashScope `run-task` protocol.
- **Flow:** `run-task` → `task-started` → binary PCM frames → `finish-task` → `task-finished`. Results arrive as `result-generated`.
- **Intermediate results** are enabled: each sentence is first streamed as revisable intermediate results (mapped to `.preview`), then closed by a final one (`.completed`), keyed by `sentence_id`.
- **Sentence splitting** is always server VAD for this model.
- **Options:** recognizer-side polishing (filler and repeated-word removal; off by default because the LLM step already does this), and `keep_dialect` which is set automatically when the language is Cantonese.

For both Bailian models the **Workspace ID** is validated (`[A-Za-z0-9-]+`). A custom `wss://` URL (no embedded credentials) overrides the derived host.

### DeepSeek

- **Endpoint:** `POST https://api.deepseek.com/v1/tools/asr`, `multipart/form-data` with a WAV file part.
- **Not streaming.** The client buffers PCM in memory while you record and uploads it when you finish. No live text is shown.
- **Limits:** a request accepts up to 120 s and 8 MiB. Recordings are split into segments of at most 110 s on sample boundaries and transcribed one after another; each becomes a `completed` event (`segment-0`, `segment-1`, …) in order.
- **Finalize timeout:** 90 s (upload and recognition happen after recording ends). Request timeout: 60 s.
- **Connection test:** sends a 0.5 s silent clip, which is billed as 1 second.

### Failure mapping

`ASRError` distinguishes configuration errors, auth (401 / 403), rate limit (429), timeout, disconnect, server error events and transcription failure. Each has a localized user message. On any failure after some text was recognized, the text is kept for copying.

## LLM providers

`HTTPLLMProvider` speaks three wire protocols. A profile chooses one, plus a Base URL, Model ID, timeout, system prompt and optional reasoning effort.

| Format | Path | Auth header | Request shape |
| --- | --- | --- | --- |
| OpenAI Responses | `/responses` | `Authorization: Bearer` | `model`, `instructions`, `input`, `store: false` |
| OpenAI Chat Completions | `/chat/completions` | `Authorization: Bearer` | `model`, `messages` (system + user) |
| Anthropic Messages | `/messages` | `x-api-key`, `anthropic-version: 2023-06-01` | `model`, `max_tokens: 4096`, `system`, `messages` |

Default Base URLs are `https://api.openai.com/v1` and `https://api.anthropic.com/v1`. Any OpenAI-compatible third-party service works with the first two formats.

**Base URL handling.** Trailing slashes and a trailing `/chat/completions`, `/responses` or `/messages` are stripped, then the format's path is appended once. The URL must be `https`, with a host, no credentials and no query string.

**Reasoning effort.** When non-empty, it is sent as `reasoning: {effort}` (Responses), `reasoning_effort` (Chat Completions) or `output_config: {effort}` (Anthropic). Empty means the parameter is omitted.

**Input.** The transcript is wrapped as a fixed user message: a one-line instruction followed by the text in a fenced block. The system prompt carries all rules.

**Output.** Response parsers extract the text and the token usage (input and output tokens) from each format. Empty output raises `emptyOutput`. Usage feeds the Home statistics.

**Errors.** `LLMError` covers invalid config, missing key, auth, model not found, rate limit, timeout, network, server error (with HTTP status) and bad response.

### Prompts

All prompts live in `TextProcessor` (`OpenType/Services/LLM/LLMProvider.swift`). The built-in prompts are written in Chinese; Say It for Me and cleanup are instructed to keep the speaker's language.

| Prompt | Used for | Notes |
| --- | --- | --- |
| `defaultSystemPrompt` | Dictation cleanup | Fix errors and homophones, drop filler and repetition, keep the final self-correction, add punctuation, keep facts and terms, do not translate or answer. A profile can override it. |
| Deep cleanup suffix | Deep cleanup level | Allows reordering and paragraphs without changing facts. |
| `translationSystemPrompt(target:region:)` | Voice translation | Independent of the cleanup prompt. Adds a regional rule for Brazilian / European Portuguese and Taiwan / Hong Kong-Macau Traditional Chinese. |
| `defaultHelpMeSayPrompt` | Say It for Me | Understand intent, write in first person, elaborate without inventing names, numbers, dates or links, keep the language, match length to the input. User-editable. |
| `helpMeSayTranslationAddendum` | Translate & Say It for Me | Overrides "keep the language": the finished message is written in the target language. |
| `webSearchAddendum(for:)` | Web search | Three wordings matching conservative, balanced and aggressive. |
| `dictionaryAddendum(entries:)` | All modes | Appended when the transcript mentions dictionary words. |

Final prompt assembly for each mode:

- Dictation: `systemPrompt(base, level)` + dictionary addendum.
- Translation: `translationSystemPrompt` + dictionary addendum.
- Say It for Me: `helpMeSaySystemPrompt(custom)` [+ translation addendum] [+ web search addendum] + dictionary addendum.

## Web search for Say It for Me

DeepSeek only, with its own API key (`deepseek_web_search_api_key`). Off by default.

When enabled and the eagerness slider is above 0%, Say It for Me and Translate & Say It for Me **ignore** the selected AI profile and instead call a fixed configuration:

- Base URL `https://api.deepseek.com`, Chat Completions format, model `deepseek-flash`.
- The request declares DeepSeek's server-side tool: `tools: [{"type": "deepseek_web_search"}]`.
- Searching and page reading run entirely on DeepSeek's servers; the client needs no tool-call loop. The model decides whether to search.
- `stream: true` with `stream_options.include_usage`, because progress events (`server_tool_event`) exist only in the stream, and the final chunk carries the token counts.
- Timeout: fixed at 180 s.

**Eagerness levels** map the 0 to 100 slider (default 80) to `WebSearchLevel`:

| Slider | Level | Thinking mode | Prompt addendum |
| --- | --- | --- | --- |
| 0% | off | n/a | none |
| 1 to 33% | conservative | off (quick lookup) | Search only on explicit verification requests or when fresh info is essential; one or two searches |
| 34 to 66% | balanced | on (`thinking: {type: enabled}`) | Search for concrete verifiable facts the model is unsure about |
| 67 to 100% | aggressive | on | Must search whenever concrete real-world facts appear |

**Progress.** `WebSearchProgress.apply(event:)` interprets `call_started` and `call_completed` events (search, `open_page` / `read_link`, `find_in_page`) to maintain counts of searches, results and pages read, plus a live activity label. The coordinator shows it in the overlay while processing. After insertion, a note reports the tally (or that the model did not search).

**Failure.** A missing key produces an error. It does **not** silently fall back to another model. The Settings connection test sends a tiny request with the tool declared.

**Billing.** DeepSeek charges web tool usage separately from tokens.

The request builder also supports the tool for the OpenAI Responses and Anthropic formats, but the app only uses the Chat Completions form against DeepSeek.

## Adding a provider

### A new ASR provider

1. Add a case to `ASRProvider` (and a model enum case if needed) in `SettingsStore.swift`, with a Settings section in `SettingsView.swift`.
2. Create an `ASRService` implementation. Use one of the existing clients as a template. For a non-streaming API, follow `DeepSeekASR` (buffer in `sendAudio`, transcribe in `finish`).
3. Extend `ASRConfig` and `DictationSessionCoordinator.asrConfig()` to read credentials and build the config. Add a `CredentialAccount` constant for the key.
4. Return it from the default `makeASR` factory in the coordinator initializer.
5. Add tests next to `DeepSeekASRTests` and `ASRConfigTests`.

### A new LLM wire protocol

1. Add a case to `LLMAPIFormat` with its default Base URL and path.
2. Handle it in `LLMRequestBuilder.makeRequest` and in `LLMResponseParser` (text and token usage).
3. Add cases to `LLMAdapterTests`.
4. Add the user-visible name to the Settings picker and the localized strings.
