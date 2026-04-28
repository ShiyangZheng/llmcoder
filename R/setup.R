# ============================================================
#  llmcoder — session configuration helpers
# ============================================================

#' Configure LLMcoder for the current session
#'
#' Sets the LLM provider, API key, model, and related options for the current R
#' session.  For **permanent** configuration that survives restarts, use
#' **Addins > LLMcoder Settings**, which writes to \code{~/.Rprofile}.
#'
#' @param provider Character.  One of `"openai"`, `"anthropic"`,
#'   `"deepseek"`, `"ollama"`, `"groq"`, `"together"`, `"openrouter"`, or
#'   `"custom"`.
#' @param api_key Character.  Your API key.  Not required when
#'   `provider = "ollama"`.
#' @param model Character.  Model identifier.  If `NULL` or `""`, a sensible
#'   default is chosen for the provider (see **Details**).
#' @param context_lines Integer.  Number of lines of code above the cursor that
#'   are sent as context to the LLM (default `40`).  Higher values improve
#'   suggestion quality but increase latency and token cost.
#' @param ollama_url Character.  Base URL of the Ollama server (default
#'   `"http://localhost:11434"`).  Only used when `provider = "ollama"`.
#' @param custom_url Character.  Base URL of a custom OpenAI-compatible server
#'   (e.g. `"http://localhost:1234/v1"` for LM Studio).  Only used when
#'   `provider = "custom"`.
#'
#' @return Invisible `NULL`.
#'
#' @details
#' **Provider defaults:**
#'
#' | Provider      | Default model                        | Notes                         |
#' |---------------|--------------------------------------|-------------------------------|
#' | `openai`      | `gpt-4o-mini`                        | Fast, cost-effective          |
#' | `anthropic`   | `claude-sonnet-4-20250514`           | Strongest reasoning           |
#' | `deepseek`    | `deepseek-chat`                      | Very cheap, great code quality|
#' | `ollama`      | `llama3`                             | No API key, fully local       |
#' | `groq`        | `llama-3.3-70b-versatile`            | Extremely fast inference      |
#' | `together`    | `meta-llama/Llama-3-70b-chat-hf`    | Large open-source model choice|
#' | `openrouter`  | `openai/gpt-4o-mini`                 | Unified gateway for 100+ models|
#' | `custom`      | `""` (must specify)                  | Any OpenAI-compat endpoint    |
#'
#' @examples
#' \dontrun{
#' # OpenAI
#' llmcoder_setup("openai", api_key = Sys.getenv("OPENAI_API_KEY"))
#' llmcoder_setup("openai", api_key = Sys.getenv("OPENAI_API_KEY"), model = "gpt-4o")
#'
#' # Anthropic Claude
#' llmcoder_setup("anthropic", api_key = Sys.getenv("ANTHROPIC_API_KEY"))
#'
#' # DeepSeek (cheapest, excellent code quality)
#' llmcoder_setup("deepseek", api_key = Sys.getenv("DEEPSEEK_API_KEY"))
#'
#' # Ollama — fully local, no API key needed
#' llmcoder_setup("ollama", model = "qwen2.5-coder:7b")
#' llmcoder_setup("ollama", model = "codellama:13b",
#'                ollama_url = "http://192.168.1.10:11434")  # remote server
#'
#' # Groq — extremely fast inference on open models
#' llmcoder_setup("groq",
#'   api_key = Sys.getenv("GROQ_API_KEY"),
#'   model   = "llama-3.3-70b-versatile")
#'
#' # Together AI — wide open-source model selection
#' llmcoder_setup("together",
#'   api_key = Sys.getenv("TOGETHER_API_KEY"),
#'   model   = "mistralai/Mixtral-8x7B-Instruct-v0.1")
#'
#' # OpenRouter — unified gateway, supports 100+ models
#' llmcoder_setup("openrouter",
#'   api_key = Sys.getenv("OPENROUTER_API_KEY"),
#'   model   = "anthropic/claude-3.5-sonnet")
#'
#' # LM Studio or any OpenAI-compatible local server
#' llmcoder_setup("custom",
#'   api_key    = "lm-studio",
#'   model      = "local-model",
#'   custom_url = "http://localhost:1234/v1")
#'
#' # Reduce context window to save tokens
#' llmcoder_setup("openai",
#'   api_key       = Sys.getenv("OPENAI_API_KEY"),
#'   context_lines = 20L)
#' }
#'
#' @seealso [llmcoder_config()], [addin_settings()]
#' @export
llmcoder_setup <- function(
    provider      = c("openai", "anthropic", "deepseek",
                      "ollama", "groq", "together", "openrouter", "custom"),
    api_key       = NULL,
    model         = NULL,
    context_lines = 40L,
    ollama_url    = "http://localhost:11434",
    custom_url    = "") {

  provider <- match.arg(provider)

  local_providers <- c("ollama")
  if (!provider %in% local_providers &&
      (is.null(api_key) || nchar(api_key) == 0)) {
    stop("Please supply an api_key (not needed for 'ollama').", call. = FALSE)
  }

  defaults <- c(
    openai     = "gpt-4o-mini",
    anthropic  = "claude-sonnet-4-20250514",
    deepseek   = "deepseek-chat",
    ollama     = "llama3",
    groq       = "llama-3.3-70b-versatile",
    together   = "meta-llama/Llama-3-70b-chat-hf",
    openrouter = "openai/gpt-4o-mini",
    custom     = ""
  )

  if (is.null(model) || nchar(model) == 0) model <- defaults[[provider]]

  options(
    llmcoder.provider      = provider,
    llmcoder.api_key       = api_key %||% "",
    llmcoder.model         = model,
    llmcoder.context_lines = as.integer(context_lines),
    llmcoder.ollama_url    = ollama_url,
    llmcoder.custom_url    = custom_url
  )

  message(sprintf(
    "llmcoder configured: provider=%s, model=%s, context_lines=%d",
    provider, model, as.integer(context_lines)
  ))
  invisible(NULL)
}


#' Show the current LLMcoder configuration
#'
#' Returns (and prints) the active provider, model, API key (masked),
#' context-lines setting, and any provider-specific URLs.
#'
#' @return An object of class `"llmcoder_config"`: a named list with elements
#'   `provider`, `model`, `api_key`, `context_lines`, `ollama_url`, and
#'   `custom_url`.  The API key is masked for security.  When printed, it
#'   displays in a human-readable table.
#'
#' @examples
#' # Show current configuration (reads from option values)
#' llmcoder_config()
#'
#' # Capture the config as a list for programmatic use
#' cfg <- llmcoder_config()
#' cfg$provider
#' cfg$model
#'
#' @seealso [llmcoder_setup()]
#' @export
llmcoder_config <- function() {
  key_raw <- getOption("llmcoder.api_key", "")
  key_display <- if (nchar(key_raw) > 4)
    paste0(substr(key_raw, 1, 4), strrep("*", nchar(key_raw) - 4))
  else if (nchar(key_raw) > 0) "****"
  else "(not set)"

  cfg <- list(
    provider      = getOption("llmcoder.provider",      "(not set)"),
    model         = getOption("llmcoder.model",         "(not set)"),
    api_key       = key_display,
    context_lines = getOption("llmcoder.context_lines", 40L),
    ollama_url    = getOption("llmcoder.ollama_url",    "http://localhost:11434"),
    custom_url    = getOption("llmcoder.custom_url",    "")
  )
  class(cfg) <- "llmcoder_config"
  cfg
}

#' @export
print.llmcoder_config <- function(x, ...) {
  cat("llmcoder configuration:\n")
  cat("  Provider      :", x$provider,      "\n")
  cat("  Model         :", x$model,         "\n")
  cat("  API key       :", x$api_key,       "\n")
  cat("  Context lines :", x$context_lines, "\n")
  cat("  Ollama URL    :", x$ollama_url,    "\n")
  if (nchar(x$custom_url) > 0)
    cat("  Custom URL    :", x$custom_url,   "\n")
  invisible(x)
}

# Null-coalescing (also defined in gadgets.R — keep consistent)
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && nchar(as.character(a)[1]) > 0) a else b
