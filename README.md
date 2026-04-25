# llmcoder

> Write a comment. Get working R code. Instantly.

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/llmcoder)](https://CRAN.R-project.org/package=llmcoder)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

**llmcoder** is an RStudio addin that integrates LLM assistance directly into
your coding workflow.  Place your cursor on a `#` comment line, press a
keyboard shortcut, and receive working R code below — no browser, no
copy-pasting.  It also auto-fixes console errors and explains selected code
as inline comments.

---

## Installation

```r
# From CRAN
install.packages("llmcoder")

# Development version
remotes::install_github("ShiyangZheng/llmcoder")
```

---

## Quick Setup

```r
library(llmcoder)

# OpenAI
llmcoder_setup("openai", api_key = Sys.getenv("OPENAI_API_KEY"))

# Anthropic Claude
llmcoder_setup("anthropic", api_key = Sys.getenv("ANTHROPIC_API_KEY"))

# DeepSeek — very cheap, great code quality
llmcoder_setup("deepseek", api_key = Sys.getenv("DEEPSEEK_API_KEY"))

# Groq — ultra-fast open-model inference
llmcoder_setup("groq", api_key = Sys.getenv("GROQ_API_KEY"))

# Ollama — fully local, no API key needed (requires `ollama serve`)
llmcoder_setup("ollama", model = "qwen2.5-coder:7b")

# OpenRouter — unified gateway to 100+ models
llmcoder_setup("openrouter", api_key = Sys.getenv("OPENROUTER_API_KEY"),
               model = "anthropic/claude-3.5-sonnet")

# LM Studio or any OpenAI-compatible local server
llmcoder_setup("custom", api_key = "lm-studio",
               model = "local-model", custom_url = "http://localhost:1234/v1")
```

Or configure via the GUI: **Addins → LLMcoder Settings**.

---

## Features

### 1. Generate code from a comment

Addins → **Generate Code from Comment** (`Ctrl+Shift+G`)

Write a `#` comment, place the cursor on it, and trigger the addin:

```r
library(tidyverse)
data <- read_csv("data/idiom_results.csv")

# fit a mixed model: RT ~ condition + (1|participant) + (1|item)
```

Generated and inserted below:

```r
library(lme4)
model <- lmer(RT ~ condition + (1 | participant) + (1 | item),
              data = data, REML = TRUE)
summary(model)
```

### 2. Generate with preview

Addins → **Generate Code (with Preview)** (`Ctrl+Shift+P`)

Same as above, but opens an editable dialog before inserting code.

### 3. Fix the last console error

Addins → **Fix Last Console Error** (`Ctrl+Shift+F`)

1. Run code → error in console.
2. Trigger this addin.
3. Review diff-style fix → click **Apply Fix**.

The addin tries `rlang::last_error()` first (best for tidyverse code), then
falls back to base R's `.Last.error`.

### 4. Fix a selected error message

Addins → **Fix Selected Error Text**

Paste the error from the console, select it, trigger this addin.

### 5. Explain selected code

Addins → **Explain Selected Code** (`Ctrl+Shift+E`)

Select a code block → inline `#` explanations appear above it.

---

## Supported Providers

| Provider     | Default model                        | Notes                           |
|--------------|--------------------------------------|---------------------------------|
| `openai`     | `gpt-4o-mini`                        | platform.openai.com             |
| `anthropic`  | `claude-sonnet-4-20250514`           | console.anthropic.com           |
| `deepseek`   | `deepseek-chat`                      | Very cheap, strong code         |
| `groq`       | `llama-3.3-70b-versatile`            | Extremely fast inference        |
| `together`   | `meta-llama/Llama-3-70b-chat-hf`    | Wide open-source model choice   |
| `openrouter` | `openai/gpt-4o-mini`                 | 100+ models, one key            |
| `ollama`     | `llama3`                             | Fully local, no API key         |
| `custom`     | *(must specify)*                     | LM Studio, vLLM, llama.cpp, …   |

### Ollama quick start

```bash
# macOS / Linux
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5-coder:7b
ollama serve          # keep running in the background
```

```r
llmcoder_setup("ollama", model = "qwen2.5-coder:7b")
ollama_list_models()  # list all installed models
```

---

## Keyboard Shortcuts

Bind in **Tools → Modify Keyboard Shortcuts → search "llmcoder"**.

| Addin                        | Windows / Linux   | macOS         |
|------------------------------|-------------------|---------------|
| Generate Code from Comment   | `Ctrl+Shift+G`    | `Cmd+Shift+G` |
| Generate Code (with Preview) | `Ctrl+Shift+P`    | `Cmd+Shift+P` |
| Fix Last Console Error       | `Ctrl+Shift+F`    | `Cmd+Shift+F` |
| Explain Selected Code        | `Ctrl+Shift+E`    | `Cmd+Shift+E` |

---

## Context Awareness

The addin sends the **N lines above your comment** as context (default `N = 40`),
so the model can:

- Infer variable names already in scope
- Match your code style (tidyverse vs base R)
- Avoid re-importing packages already loaded

Adjust with `context_lines`:

```r
llmcoder_setup("openai", api_key = "...", context_lines = 20L)
```

---

## Security

API keys written to `~/.Rprofile` are **plaintext**.  Use `~/.Renviron` for
better security:

```
OPENAI_API_KEY=sk-...
```

Then: `llmcoder_setup("openai", api_key = Sys.getenv("OPENAI_API_KEY"))`

---

## Citation

```r
citation("llmcoder")
```

> Zheng, S. (2025). *llmcoder: LLM-Powered Code Generation and Error Fixing
> for RStudio*. R package version 0.1.0.
> <https://github.com/ShiyangZheng/llmcoder>

---

## Author

**Shiyang Zheng** — PhD candidate in Psycholinguistics, University of Nottingham  
Email: [Shiyang.Zheng@nottingham.ac.uk](mailto:Shiyang.Zheng@nottingham.ac.uk)

---

## License

MIT © Shiyang Zheng
