# ============================================================
#  llmcoder — LLM API layer
# ============================================================

#' Call the configured LLM
#'
#' Unified dispatch function that reads provider, model, and credentials from
#' options (set via [llmcoder_setup()] or **Addins \→ LLMcoder Settings**) and
#' forwards the request to the appropriate backend.
#'
#' @param prompt       Character. The user-facing instruction.
#' @param system_prompt Character. The system-level instruction for the model.
#' @param context      Character or `NULL`. Surrounding R code sent as
#'   additional context (prepended to `prompt`).
#'
#' @return Character string containing the model's response text.
#'
#' @details
#' Supported providers:
#' \describe{
#'   \item{`"openai"`}{OpenAI Chat Completions API
#'     (`https://api.openai.com/v1`).}
#'   \item{`"anthropic"`}{Anthropic Messages API
#'     (`https://api.anthropic.com/v1/messages`).}
#'   \item{`"deepseek"`}{DeepSeek Chat API, OpenAI-compatible
#'     (`https://api.deepseek.com/v1`).}
#'   \item{`"ollama"`}{Local Ollama server (default
#'     `http://localhost:11434`).  No API key required.}
#'   \item{`"groq"`}{Groq Cloud API, OpenAI-compatible
#'     (`https://api.groq.com/openai/v1`).  Extremely fast inference.}
#'   \item{`"together"`}{Together AI API, OpenAI-compatible
#'     (`https://api.together.xyz/v1`).  Wide open-source model selection.}
#'   \item{`"openrouter"`}{OpenRouter API, OpenAI-compatible
#'     (`https://openrouter.ai/api/v1`).  Unified gateway to 100+ models.}
#'   \item{`"custom"`}{Any OpenAI-compatible server.  Set
#'     `llmcoder.custom_url` to the base URL (e.g.\
#'     `"http://localhost:1234/v1"` for LM Studio).}
#' }
#'
#' @examples
#' \dontrun{
#' llmcoder_setup("ollama", model = "llama3")
#' resp <- call_llm(
#'   prompt        = "Write R code to compute the mean of a numeric vector",
#'   system_prompt = "You are an R programming assistant.",
#'   context       = NULL
#' )
#' cat(resp)
#' }
#'
#' @keywords internal
call_llm <- function(prompt, system_prompt, context = NULL) {

  provider   <- getOption("llmcoder.provider",   "openai")
  api_key    <- getOption("llmcoder.api_key",    Sys.getenv("LLMCODER_API_KEY"))
  model      <- getOption("llmcoder.model",      default_model(provider))
  ollama_url <- getOption("llmcoder.ollama_url", "http://localhost:11434")

  if (is.null(provider) || !nzchar(trimws(provider))) {
    stop(
      "llmcoder.provider option is not set. ",
      "Run llmcoder_setup() or use the Settings addin to configure your provider.",
      call. = FALSE
    )
  }

  # Local / keyless providers
  local_providers <- c("ollama")
  if (!provider %in% local_providers &&
      (is.null(api_key) || nchar(api_key) == 0)) {
    stop(
      "No API key found. Run `llmcoder_setup()` or set the ",
      "LLMCODER_API_KEY environment variable.", call. = FALSE
    )
  }

  # Inject context
  full_prompt <- if (!is.null(context) && nchar(trimws(context)) > 0) {
    paste0(
      "Here is the surrounding R code for context:\n```r\n",
      context, "\n```\n\n", prompt
    )
  } else {
    prompt
  }

  switch(provider,
    openai = call_openai_compat(
      full_prompt, system_prompt, api_key, model,
      base_url = "https://api.openai.com/v1"),

    anthropic = call_anthropic(
      full_prompt, system_prompt, api_key, model),

    deepseek = call_openai_compat(
      full_prompt, system_prompt, api_key, model,
      base_url = "https://api.deepseek.com/v1"),

    ollama = call_ollama(
      full_prompt, system_prompt, model, base_url = ollama_url),

    groq = call_openai_compat(
      full_prompt, system_prompt, api_key, model,
      base_url = "https://api.groq.com/openai/v1"),

    together = call_openai_compat(
      full_prompt, system_prompt, api_key, model,
      base_url = "https://api.together.xyz/v1"),

    openrouter = call_openai_compat(
      full_prompt, system_prompt, api_key, model,
      base_url    = "https://openrouter.ai/api/v1",
      extra_hdrs  = list(
        "HTTP-Referer" = "https://github.com/ShiyangZheng/llmcoder",
        "X-Title"      = "llmcoder"
      )),

    custom = {
      custom_url <- getOption("llmcoder.custom_url", "")
      if (nchar(trimws(custom_url)) == 0)
        stop(
          "Set the 'llmcoder.custom_url' option (or use the Settings addin) ",
          "before using the 'custom' provider.", call. = FALSE
        )
      call_openai_compat(full_prompt, system_prompt, api_key, model,
                         base_url = custom_url)
    },

    stop(
      "Unknown provider: '", provider, "'. ",
      "Valid choices: openai, anthropic, deepseek, ollama, ",
      "groq, together, openrouter, custom.", call. = FALSE
    )
  )
}


# ---------- Provider implementations ------------------------------------------

#' Generic OpenAI-compatible chat completions call
#' @keywords internal
call_openai_compat <- function(prompt, system_prompt, api_key, model,
                                base_url, extra_hdrs = character()) {

  hdrs <- c(
    "Authorization" = paste("Bearer", api_key),
    "Content-Type"  = "application/json",
    unname(extra_hdrs)
  )

  body_data <- list(
    model       = model,
    messages    = list(
      list(role = "system", content = system_prompt),
      list(role = "user",   content = prompt)
    ),
    temperature = 0.2,
    max_tokens  = 2000
  )

  base <- httr2::request(paste0(trimws(base_url, "right"), "/chat/completions"))

  # Build headers using do.call (avoids non-standard-evaluation issues in pipeline)
  req <- do.call(httr2::req_headers, c(list(.req = base), hdrs))
  req <- httr2::req_body_json(req, data = body_data)
  req <- httr2::req_error(req, is_error = \(r) FALSE)
  req <- httr2::req_timeout(req, 120)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("API error (", httr2::resp_status(resp), "): ",
         body$error$message, call. = FALSE)
  }

  content <- body$choices[[1]]$message$content
  if (is.null(content) || !is.character(content) || length(content) == 0) {
    stop(
      "LLM returned empty content. ",
      "The model may have returned a tool/function call instead of text.",
      call. = FALSE
    )
  }
  content
}

#' Anthropic Messages API call
#' @keywords internal
call_anthropic <- function(prompt, system_prompt, api_key, model) {

  req <- httr2::request("https://api.anthropic.com/v1/messages") |>
    httr2::req_headers(
      "x-api-key"         = api_key,
      "anthropic-version" = "2023-06-01",
      "Content-Type"      = "application/json"
    ) |>
    httr2::req_body_json(data = list(
      model      = model,
      max_tokens = 2000,
      system     = system_prompt,
      messages   = list(list(role = "user", content = prompt))
    )) |>
    httr2::req_error(is_error = \(r) FALSE) |>
    httr2::req_timeout(120)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("Anthropic API error (", httr2::resp_status(resp), "): ",
         body$error$message, call. = FALSE)
  }
  body$content[[1]]$text
}

#' Ollama local API (uses the OpenAI-compatible /v1 endpoint, Ollama >= 0.1.24)
#'
#' No API key is required.  The Ollama server must be running locally;
#' start it with `ollama serve` in a terminal.
#' @keywords internal
call_ollama <- function(prompt, system_prompt, model, base_url) {
  call_openai_compat(
    prompt        = prompt,
    system_prompt = system_prompt,
    api_key       = "ollama",   # accepted but ignored by Ollama
    model         = model,
    base_url      = paste0(trimws(base_url, "right"), "/v1")
  )
}


# ---------- Helpers -----------------------------------------------------------

#' Default model name per provider
#'
#' Returns a sensible default model name when the user has not specified one
#' explicitly.
#'
#' @param provider Character. Provider identifier (see [call_llm()]).
#' @return Character string with the default model name.
#' @examples
#' \dontrun{
#' default_model("openai")
#' default_model("anthropic")
#' default_model("ollama")
#' }
#' @keywords internal
default_model <- function(provider) {
  switch(provider,
    openai     = "gpt-4o-mini",
    anthropic  = "claude-sonnet-4-20250514",
    deepseek   = "deepseek-chat",
    ollama     = "llama3",
    groq       = "llama-3.3-70b-versatile",
    together   = "meta-llama/Llama-3-70b-chat-hf",
    openrouter = "openai/gpt-4o-mini",
    custom     = "",
    "gpt-4o-mini"
  )
}


#' List models available on a running Ollama server
#'
#' Queries `GET /api/tags` on the local Ollama REST API and returns the names
#' of all installed models.  Useful for populating the model selector in the
#' Settings gadget.
#'
#' @param base_url Character. Ollama base URL.  Defaults to the value of
#'   `getOption("llmcoder.ollama_url", "http://localhost:11434")`.
#' @return Character vector of model tag names, or `NULL` if Ollama is not
#'   reachable.
#'
#' @details
#' Ollama must be running (`ollama serve`) before calling this function.
#' Models are installed with `ollama pull <model>` from the terminal.
#'
#' @examples
#' \dontrun{
#' ollama_list_models()
#' # [1] "llama3:latest"  "qwen2.5-coder:7b"  "mistral:latest"
#' }
#'
#' @export
ollama_list_models <- function(base_url = getOption("llmcoder.ollama_url",
                                                     "http://localhost:11434")) {
  url <- paste0(trimws(base_url, "right"), "/api/tags")
  tryCatch({
    req  <- httr2::request(url) |> httr2::req_timeout(5)
    resp <- httr2::req_perform(req)
    body <- httr2::resp_body_json(resp)
    vapply(body$models, `[[`, character(1), "name")
  }, error = function(e) {
    message("Could not reach Ollama at ", base_url,
            ".\nIs it running? Try: ollama serve")
    NULL
  })
}


# ---------- System prompts ----------------------------------------------------

#' System prompt for code generation
#' @keywords internal
build_system_prompt <- function() {
  paste0(
    "You are an expert R programmer assisting a researcher inside RStudio. ",
    "The user will provide a comment written in R (prefixed with #) describing ",
    "the code they want. Your task:\n",
    "1. Output ONLY raw R code \u2014 no markdown fences, no explanations, no preamble.\n",
    "2. The code must directly implement what the comment requests.\n",
    "3. Use tidyverse idioms (dplyr, ggplot2, tidyr, purrr) when appropriate.\n",
    "4. Keep variable names concise and meaningful.\n",
    "5. Add brief inline comments only where logic is non-obvious.\n",
    "6. If the comment is ambiguous, implement the most reasonable interpretation.\n",
    "7. Do NOT reproduce the original comment \u2014 only output the code.\n",
    "The user's field is psycholinguistics / applied linguistics. ",
    "Prefer lme4/lmerTest for mixed models, ggplot2 for visualisation, ",
    "and tidyverse for data wrangling."
  )
}

#' System prompt for code explanation
#'
#' Returns the system prompt instructing the LLM to write R comments
#' explaining the user's selected code.
#'
#' @return Character string: the system prompt sent to the LLM for the
#'   explain workflow.
#' @examples
#' \dontrun{
#' build_explain_prompt()
#' }
#' @keywords internal
build_explain_prompt <- function() {
  paste0(
    "You are an expert R programmer. The user will provide R code. ",
    "Write a clear, concise explanation as R comments (each line prefixed with # ). ",
    "Output ONLY the comment lines \u2014 no code, no markdown. ",
    "Focus on what the code does and why, not how R syntax works."
  )
}

#' System prompt for error fixing
#'
#' Returns the system prompt instructing the LLM to diagnose an R error and
#' produce corrected code.
#'
#' @return Character string: the system prompt sent to the LLM for the
#'   fix workflow.
#' @examples
#' \dontrun{
#' build_fix_prompt()
#' }
#' @keywords internal
build_fix_prompt <- function() {
  paste0(
    "You are an expert R programmer debugging code inside RStudio. ",
    "The user will provide:\n",
    "  (a) An R error message from the console.\n",
    "  (b) The R source code that produced it.\n\n",
    "Your task:\n",
    "1. Diagnose the root cause of the error.\n",
    "2. Output the COMPLETE corrected source code \u2014 not just the changed lines.\n",
    "3. Mark each changed line with a short comment: # FIX: <reason>.\n",
    "4. Output ONLY raw R code \u2014 no markdown fences, no preamble, no explanation outside comments.\n",
    "5. Preserve all existing formatting and unrelated comments.\n",
    "6. If there are multiple plausible fixes, choose the most conservative one.\n",
    "The user's field is psycholinguistics / applied linguistics."
  )
}


# ============================================================
#  llmcoder — Multi-turn message history API
# ============================================================

#' Call the configured LLM with full message history
#'
#' Like [call_llm()] but accepts a `messages` list that preserves the full
#' conversation context across multiple turns.  This is the engine behind
#' [addin_chat_panel()].
#'
#' @param messages List of messages, each element being
#'   `list(role = "system"|"user"|"assistant", content = "...")`.
#'   The **last** message must have `role = "user"`.
#' @param system_prompt_override  Optional character string.  If supplied,
#'   it **replaces** the system role message in `messages` entirely
#'   (useful for swapping in a custom persona at call-time).
#'
#' @return Character string: the model's response text.
#'
#' @keywords internal
call_llm_history <- function(messages, system_prompt_override = NULL) {

  provider   <- getOption("llmcoder.provider",   "openai")
  api_key    <- getOption("llmcoder.api_key",    Sys.getenv("LLMCODER_API_KEY"))
  model      <- getOption("llmcoder.model",       default_model(provider))
  ollama_url <- getOption("llmcoder.ollama_url", "http://localhost:11434")

  # Guard against NULL / empty provider (R switch silently returns NULL for these)
  if (is.null(provider) || !nzchar(trimws(provider))) {
    stop(
      "llmcoder.provider option is not set. ",
      "Run llmcoder_setup() or use the Settings addin to configure your provider.",
      call. = FALSE
    )
  }

  local_providers <- c("ollama")
  if (!provider %in% local_providers &&
      (is.null(api_key) || nchar(api_key) == 0)) {
    stop(
      "No API key found. Run `llmcoder_setup()` or set the ",
      "LLMCODER_API_KEY environment variable.", call. = FALSE
    )
  }

  # Optionally replace system message
  msgs <- messages
  if (!is.null(system_prompt_override)) {
    sys_idx <- which(vapply(msgs, `[[`, logical(1), "role") == "system")
    if (length(sys_idx) > 0) {
      msgs[[sys_idx[[1]]]] <- list(role = "system", content = system_prompt_override)
    } else {
      msgs <- c(list(list(role = "system", content = system_prompt_override)), msgs)
    }
  }

  switch(provider,
    openai = call_openai_compat_history(
      msgs, api_key, model, base_url = "https://api.openai.com/v1"),

    anthropic = call_anthropic_history(
      msgs, api_key, model),

    deepseek = call_openai_compat_history(
      msgs, api_key, model, base_url = "https://api.deepseek.com/v1"),

    ollama = call_ollama_history(
      msgs, model, base_url = ollama_url),

    groq = call_openai_compat_history(
      msgs, api_key, model, base_url = "https://api.groq.com/openai/v1"),

    together = call_openai_compat_history(
      msgs, api_key, model, base_url = "https://api.together.xyz/v1"),

    openrouter = call_openai_compat_history(
      msgs, api_key, model,
      base_url    = "https://openrouter.ai/api/v1",
      extra_hdrs  = list(
        "HTTP-Referer" = "https://github.com/ShiyangZheng/llmcoder",
        "X-Title"      = "llmcoder"
      )),

    custom = {
      custom_url <- getOption("llmcoder.custom_url", "")
      if (nchar(trimws(custom_url)) == 0)
        stop("Set the 'llmcoder.custom_url' option before using the 'custom' provider.",
             call. = FALSE)
      call_openai_compat_history(msgs, api_key, model, base_url = custom_url)
    },

    stop("Unknown provider: '", provider, "'. ",
         "Valid choices: openai, anthropic, deepseek, ollama, ",
         "groq, together, openrouter, custom.", call. = FALSE)
  )
}


#' OpenAI-compatible multi-turn call
#'
#' @param messages   List of message objects.
#' @param api_key    API key.
#' @param model      Model name.
#' @param base_url   API base URL.
#' @param extra_hdrs Named character vector of extra headers.
#' @keywords internal
call_openai_compat_history <- function(messages, api_key, model,
                                       base_url,
                                       extra_hdrs = character()) {

  hdrs <- c(
    "Authorization" = paste("Bearer", api_key),
    "Content-Type"  = "application/json",
    unname(extra_hdrs)
  )

  body_data <- list(
    model       = model,
    messages    = messages,
    temperature = 0.7,
    max_tokens  = 2000
  )

  base <- httr2::request(
    paste0(trimws(base_url, "right"), "/chat/completions")
  )

  req <- do.call(httr2::req_headers, c(list(.req = base), hdrs))
  req <- httr2::req_body_json(req, data = body_data)
  req <- httr2::req_error(req, is_error = \(r) FALSE)
  req <- httr2::req_timeout(req, 120)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("API error (", httr2::resp_status(resp), "): ",
         body$error$message, call. = FALSE)
  }

  content <- body$choices[[1]]$message$content

  # Defensive: ensure we got a character string, not a function_call or NULL
  if (is.null(content) || !is.character(content) || length(content) == 0) {
    finish_reason <- body$choices[[1]]$finish_reason %||% "(unknown)"
    stop(
      "LLM returned empty content (finish_reason = '", finish_reason, "'). ",
      "The model may have returned a tool/function call instead of text. ",
      "Check that 'tools' or 'function_call' parameters are not set.",
      call. = FALSE
    )
  }
  content
}


#' Anthropic Messages API with multi-turn history
#'
#' Extracts the system role from `messages` and moves it to the top-level
#' \code{system} field, as required by the Anthropic API.  Only
#' \code{user} and \code{assistant} roles are allowed.
#'
#' @param messages  List of message objects.
#' @param api_key   API key.
#' @param model     Model name.
#' @keywords internal
call_anthropic_history <- function(messages, api_key, model) {

  # Pull system out
  sys_content <- ""
  non_sys <- messages

  sys_idx <- which(vapply(messages, `[[`, logical(1), "role") == "system")
  if (length(sys_idx) > 0) {
    sys_content <- messages[[sys_idx[[1]]]]$content
    non_sys <- messages[-sys_idx[[1]]]
  }

  # Only user/assistant roles are permitted
  allowed_roles <- c("user", "assistant")
  anth_messages <- lapply(non_sys, function(m) {
    if (!(m$role %in% allowed_roles)) {
      list(role = "user", content = paste0("[", m$role, " message]: ", m$content))
    } else {
      m
    }
  })

  req <- httr2::request("https://api.anthropic.com/v1/messages") |>
    httr2::req_headers(
      "x-api-key"          = api_key,
      "anthropic-version"  = "2023-06-01",
      "Content-Type"       = "application/json"
    ) |>
    httr2::req_body_json(data = list(
      model      = model,
      max_tokens = 2000,
      system     = sys_content,
      messages   = anth_messages
    )) |>
    httr2::req_error(is_error = \(r) FALSE) |>
    httr2::req_timeout(120)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  if (!is.null(body$error)) {
    stop("Anthropic API error (", httr2::resp_status(resp), "): ",
         body$error$message, call. = FALSE)
  }
  body$content[[1]]$text
}


#' Ollama multi-turn (OpenAI-compatible endpoint)
#' @keywords internal
call_ollama_history <- function(messages, model, base_url) {
  call_openai_compat_history(
    messages   = messages,
    api_key    = "ollama",
    model      = model,
    base_url   = paste0(trimws(base_url, "right"), "/v1")
  )
}


# ---------- Infix helpers ----------------------------------------------------

#' Null-coalescing operator: returns x if it is non-NULL, otherwise y
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
