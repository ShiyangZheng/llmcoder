# ============================================================
#  llmcoder — Shiny mini-gadgets
# ============================================================

# ---- 1. Code preview gadget (generate) -------------------------------

#' @keywords internal
preview_gadget <- function(comment, code, row, indent, ctx_id) {

  ui <- miniUI::miniPage(
    shiny::tags$head(shiny::tags$style(gadget_css())),
    miniUI::gadgetTitleBar(
      title = shiny::tags$span(
        shiny::tags$span("\U1F916", style = "margin-right:6px;"),
        shiny::tags$em(comment, style = "font-style:italic; color:#555;")
      ),
      right = miniUI::miniTitleBarButton("insert", "Insert \u2193", primary = TRUE)
    ),
    miniUI::miniContentPanel(
      shiny::tags$textarea(
        id    = "code_edit",
        rows  = 20,
        class = "code-area",
        code
      ),
      shiny::tags$p(
        "\u2139\ufe0f Edit freely, then click \u2018Insert\u2019.",
        class = "hint"
      )
    )
  )

  server <- function(input, output, session) {
    shiny::observeEvent(input$insert, {
      if (!is.null(input$code_edit) && nchar(trimws(input$code_edit)) > 0)
        insert_after_row(input$code_edit, row, indent)
      notify("Code inserted.")
      shiny::stopApp(invisible(NULL))
    })
    shiny::observeEvent(input$cancel, shiny::stopApp(invisible(NULL)))
  }

  shiny::runGadget(ui, server,
    viewer = shiny::dialogViewer("LLMcoder Preview", width = 720, height = 540))
}


# ---- 2. Fix-error preview gadget ------------------------------------

#' @keywords internal
fix_preview_gadget <- function(error_msg, original, fixed, ctx) {

  ui <- miniUI::miniPage(
    shiny::tags$head(shiny::tags$style(gadget_css())),
    miniUI::gadgetTitleBar(
      title = "\U1F527  LLMcoder \u2014 Error Fix Preview",
      right = miniUI::miniTitleBarButton("apply", "Apply Fix", primary = TRUE)
    ),
    miniUI::miniContentPanel(
      shiny::tags$div(
        class = "error-box",
        shiny::tags$strong("Error:"),
        shiny::tags$pre(
          substr(error_msg, 1, 400),
          style = "margin:4px 0 0; font-size:11px; white-space:pre-wrap;"
        )
      ),
      shiny::tags$p(
        shiny::tags$strong("Fixed code"),
        " (lines marked ", shiny::tags$code("# FIX:"),
        " show what changed) \u2014 edit before applying:",
        class = "hint"
      ),
      shiny::tags$textarea(
        id    = "fixed_edit",
        rows  = 22,
        class = "code-area",
        fixed
      )
    )
  )

  server <- function(input, output, session) {
    shiny::observeEvent(input$apply, {
      edited <- input$fixed_edit
      if (!is.null(edited) && nchar(trimws(edited)) > 0) {
        # Replace entire document: use row count from ctx (0-indexed end)
        n_lines <- length(ctx$contents)
        # document_position rows are 1-based; last position is (n_lines, 0)
        # means "beginning of the line AFTER the last line", which safely
        # selects the full content even if the last line has no trailing newline.
        rstudioapi::modifyRange(
          location = rstudioapi::document_range(
            rstudioapi::document_position(1L, 1L),
            rstudioapi::document_position(n_lines, .Machine$integer.max)
          ),
          text = paste0(edited, "\n"),
          id   = ctx$id
        )
        notify("Fix applied.")
      }
      shiny::stopApp(invisible(NULL))
    })
    shiny::observeEvent(input$cancel, shiny::stopApp(invisible(NULL)))
  }

  shiny::runGadget(ui, server,
    viewer = shiny::dialogViewer("LLMcoder Fix Preview", width = 760, height = 640))
}


# ---- 3. Settings gadget -----------------------------------------------

#' @keywords internal
settings_gadget <- function() {

  # Current values
  cur_provider    <- getOption("llmcoder.provider",      "openai")
  cur_model       <- getOption("llmcoder.model",         "")
  cur_key         <- getOption("llmcoder.api_key",       Sys.getenv("LLMCODER_API_KEY"))
  cur_ollama_url  <- getOption("llmcoder.ollama_url",    "http://localhost:11434")
  cur_custom_url  <- getOption("llmcoder.custom_url",    "")
  cur_ctx_lines   <- getOption("llmcoder.context_lines", 40L)

  model_defaults <- list(
    openai     = "gpt-4o-mini",
    anthropic  = "claude-sonnet-4-20250514",
    deepseek   = "deepseek-chat",
    groq       = "llama-3.3-70b-versatile",
    together   = "meta-llama/Llama-3-70b-chat-hf",
    openrouter = "openai/gpt-4o-mini",
    ollama     = "llama3",
    custom     = ""
  )

  provider_choices <- c(
    "OpenAI"                          = "openai",
    "Anthropic (Claude)"              = "anthropic",
    "DeepSeek"                        = "deepseek",
    "Groq (fast open models)"         = "groq",
    "Together AI (open models)"       = "together",
    "OpenRouter (100+ models)"        = "openrouter",
    "Ollama (local)"                  = "ollama",
    "Custom / LM Studio / vLLM"       = "custom"
  )

  ui <- miniUI::miniPage(
    shiny::tags$head(shiny::tags$style(gadget_css())),
    miniUI::gadgetTitleBar(
      "\U2699\uFE0F  LLMcoder Settings",
      right = miniUI::miniTitleBarButton("save", "Save", primary = TRUE)
    ),
    miniUI::miniContentPanel(
      padding = 15,

      # --- Provider --------------------------------------------------
      shiny::selectInput("provider", "Provider",
        choices  = provider_choices,
        selected = cur_provider
      ),

      # --- Model (text + refresh for Ollama) -------------------------
      shiny::uiOutput("model_ui"),

      # --- API key (hidden for Ollama) -------------------------------
      shiny::uiOutput("key_ui"),

      # --- Ollama URL (shown only when provider == ollama) -----------
      shiny::uiOutput("ollama_url_ui"),

      # --- Custom base URL (shown only when provider == custom) ------
      shiny::uiOutput("custom_url_ui"),

      shiny::hr(),

      # --- Context lines slider -------------------------------------
      shiny::sliderInput(
        "ctx_lines",
        "Context lines sent to LLM (lines of code above cursor)",
        min   = 0, max = 150, value = cur_ctx_lines, step = 5
      ),
      shiny::tags$p(
        "More context = better suggestions, but slower and uses more tokens.",
        class = "hint"
      ),

      shiny::hr(),

      shiny::checkboxInput("save_profile",
        "Persist settings to ~/.Rprofile (survives restarts)", value = TRUE)
    )
  )

  server <- function(input, output, session) {

    # ---- Dynamic model UI ----
    output$model_ui <- shiny::renderUI({
      prov  <- input$provider %||% cur_provider
      def_m <- model_defaults[[prov]] %||% ""
      cur_m <- if (nchar(cur_model) > 0) cur_model else def_m

      if (prov == "ollama") {
        shiny::tagList(
          shiny::fluidRow(
            shiny::column(9,
              shiny::textInput("model", "Model (Ollama)",
                value       = cur_m,
                placeholder = "llama3, mistral, qwen2.5-coder, ...")
            ),
            shiny::column(3,
              shiny::tags$br(),
              shiny::actionButton("refresh_ollama", "\U1F504 Refresh",
                style = "margin-top:6px; width:100%;")
            )
          ),
          shiny::uiOutput("ollama_model_picker")
        )
      } else {
        shiny::textInput("model", "Model",
          value       = cur_m,
          placeholder = def_m)
      }
    })

    # ---- Ollama model picker (populated after Refresh) ----
    ollama_models <- shiny::reactiveVal(character(0))

    shiny::observeEvent(input$refresh_ollama, {
      url <- trimws(input$ollama_url %||% cur_ollama_url)
      if (nchar(url) == 0) url <- cur_ollama_url
      old <- getOption("llmcoder.ollama_url")
      options(llmcoder.ollama_url = url)
      models <- ollama_list_models()
      options(llmcoder.ollama_url = old)
      if (!is.null(models) && length(models) > 0) {
        ollama_models(models)
        shiny::showNotification(
          paste(length(models), "model(s) found."),
          type = "message", duration = 3
        )
      } else {
        shiny::showNotification(
          "No models found. Is `ollama serve` running?",
          type = "warning", duration = 5
        )
      }
    })

    output$ollama_model_picker <- shiny::renderUI({
      models <- ollama_models()
      if (length(models) == 0) return(NULL)
      shiny::tagList(
        shiny::selectInput("ollama_model_select",
          "Available models (click to populate Model field):",
          choices = models, selected = models[1]),
        shiny::tags$p(
          "Select a model above to populate the Model field automatically.",
          class = "hint"
        )
      )
    })

    # When user picks from the list, update the text field
    shiny::observeEvent(input$ollama_model_select, {
      shiny::updateTextInput(session, "model", value = input$ollama_model_select)
    })

    # ---- API key UI ----
    output$key_ui <- shiny::renderUI({
      prov <- input$provider %||% cur_provider
      if (prov == "ollama") return(NULL)
      placeholder <- switch(prov,
        openai     = "sk-...",
        anthropic  = "sk-ant-...",
        deepseek   = "sk-...",
        groq       = "gsk_...",
        together   = "your-together-api-key",
        openrouter = "sk-or-...",
        custom     = "your-key-or-empty",
        "your-api-key"
      )
      link_txt <- switch(prov,
        openai     = "Get key at platform.openai.com",
        anthropic  = "Get key at console.anthropic.com",
        deepseek   = "Get key at platform.deepseek.com",
        groq       = "Get key at console.groq.com",
        together   = "Get key at api.together.xyz",
        openrouter = "Get key at openrouter.ai/keys",
        NULL
      )
      shiny::tagList(
        shiny::passwordInput("api_key", "API Key",
          value       = cur_key,
          placeholder = placeholder),
        if (!is.null(link_txt))
          shiny::tags$p(link_txt, class = "hint")
      )
    })

    # ---- Ollama URL UI ----
    output$ollama_url_ui <- shiny::renderUI({
      if ((input$provider %||% cur_provider) != "ollama") return(NULL)
      shiny::tagList(
        shiny::textInput("ollama_url", "Ollama base URL",
          value       = cur_ollama_url,
          placeholder = "http://localhost:11434"),
        shiny::tags$p(
          "Default: http://localhost:11434  \u2014  start with: ollama serve",
          class = "hint"
        )
      )
    })

    # ---- Custom URL UI ----
    output$custom_url_ui <- shiny::renderUI({
      if ((input$provider %||% cur_provider) != "custom") return(NULL)
      shiny::tagList(
        shiny::textInput("custom_url", "Custom OpenAI-compatible base URL",
          value       = cur_custom_url,
          placeholder = "http://localhost:1234/v1"),
        shiny::tags$p(
          "Compatible with LM Studio, vLLM, llama.cpp server, Mistral API, etc.",
          class = "hint"
        )
      )
    })

    # ---- Save ----
    shiny::observeEvent(input$save, {
      prov       <- input$provider   %||% cur_provider
      model_val  <- input$model      %||% (model_defaults[[prov]] %||% "")
      key_val    <- input$api_key    %||% cur_key
      ctx_val    <- as.integer(input$ctx_lines %||% cur_ctx_lines)
      ollama_val <- input$ollama_url %||% cur_ollama_url
      custom_val <- input$custom_url %||% cur_custom_url

      options(
        llmcoder.provider      = prov,
        llmcoder.model         = model_val,
        llmcoder.api_key       = key_val,
        llmcoder.context_lines = ctx_val,
        llmcoder.ollama_url    = ollama_val,
        llmcoder.custom_url    = custom_val
      )

      if (isTRUE(input$save_profile)) {
        write_rprofile(prov, model_val, key_val, ctx_val, ollama_val, custom_val)
      } else {
        notify("Settings applied for this session only (not saved to .Rprofile).")
      }

      shiny::stopApp(invisible(NULL))
    })

    shiny::observeEvent(input$cancel, shiny::stopApp(invisible(NULL)))
  }

  shiny::runGadget(ui, server,
    viewer = shiny::dialogViewer("LLMcoder Settings", width = 500, height = 680))
}


# ---- Helpers -----------------------------------------------------------------

#' Write llmcoder options to ~/.Rprofile
#'
#' Writes (or replaces) an `# --- llmcoder ---` block in the user's
#' `~/.Rprofile` so that llmcoder settings persist across R sessions.
#'
#' @param provider   Character.  Provider identifier (see [llmcoder_setup()]).
#' @param model      Character.  Model name.
#' @param api_key    Character.  API key (may be `""` for Ollama).
#' @param ctx_lines  Integer.    Number of context lines.
#' @param ollama_url Character.  Ollama base URL.
#' @param custom_url Character.  Custom endpoint base URL.
#' @return Invisible `NULL`.  Called for its side-effect of writing to
#'   `~/.Rprofile`.
#' @examples
#' \dontrun{
#' write_rprofile(
#'   provider   = "ollama",
#'   model      = "llama3",
#'   api_key    = "",
#'   ctx_lines  = 40L,
#'   ollama_url = "http://localhost:11434",
#'   custom_url = ""
#' )
#' }
#' @keywords internal
write_rprofile <- function(provider, model, api_key, ctx_lines,
                            ollama_url, custom_url) {
  profile_path <- path.expand("~/.Rprofile")

  new_block <- c(
    "",
    "# --- llmcoder settings (written by addin_settings) ---",
    paste0('options(llmcoder.provider      = "', provider,   '")'),
    paste0('options(llmcoder.model         = "', model,      '")'),
    paste0('options(llmcoder.api_key       = "', api_key,    '")'),
    paste0('options(llmcoder.context_lines = ',  ctx_lines,  'L)'),
    paste0('options(llmcoder.ollama_url    = "', ollama_url, '")'),
    paste0('options(llmcoder.custom_url    = "', custom_url, '")')
  )

  existing <- if (file.exists(profile_path))
    readLines(profile_path, warn = FALSE)
  else
    character(0)

  # Remove old llmcoder block
  keep <- !stringr::str_detect(
    existing,
    "llmcoder\\.(provider|model|api_key|context_lines|ollama_url|custom_url)|llmcoder settings"
  )
  writeLines(c(existing[keep], new_block), profile_path)
  notify("Settings saved to ~/.Rprofile")
}

#' Shared CSS for all gadgets
#' @keywords internal
gadget_css <- function() {
  "
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 13px; }
  .code-area {
    width: 100%; font-family: 'Fira Code', 'JetBrains Mono', 'Courier New', monospace;
    font-size: 12.5px; border: 1px solid #ddd; border-radius: 5px;
    padding: 10px; box-sizing: border-box; resize: vertical;
    background: #f8f8f8; line-height: 1.5; color: #333;
  }
  .code-area:focus { outline: none; border-color: #4a9eff; box-shadow: 0 0 0 2px rgba(74,158,255,.2); }
  .hint { color: #888; font-size: 11px; margin-top: 5px; }
  .error-box {
    background: #fff5f5; border: 1px solid #f5c6cb; border-radius: 5px;
    padding: 8px 12px; margin-bottom: 10px;
  }
  "
}

# Null-coalescing helper
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && nchar(as.character(a)[1]) > 0) a else b
