# News

## llmcoder 0.1.0

### New features

* **Generate code from comment** — place cursor on a `# comment` line, trigger
  the addin, and receive R code inserted immediately below.
* **Generate with preview** — same as above but shows an editable Shiny dialog
  before inserting.
* **Fix last console error** — automatically captures the most recent R error
  (via `rlang::last_error()` and `.Last.error`) and requests a corrected
  version of the current file from the LLM.
* **Fix selected error text** — paste error text into the editor, select it,
  and trigger the addin for a targeted fix.
* **Explain selected code** — generates a plain-English explanation as `#`
  comments above any selected code block.
* **Settings addin** — GUI for configuring provider, model, API key, and
  context-window size; optionally persists to `~/.Rprofile`.

### Supported providers

OpenAI, Anthropic (Claude), DeepSeek, Groq, Together AI, OpenRouter,
Ollama (fully local, no API key required), and any custom OpenAI-compatible
endpoint (LM Studio, vLLM, llama.cpp, etc.).
