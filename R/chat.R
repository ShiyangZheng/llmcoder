# ============================================================
#  llmcoder - Chat Panel (multi-turn Shiny gadget)
# ============================================================

# ---------- CSS ---------------------------------------------------------------

#' @importFrom htmltools HTML
#' @importFrom shiny dialogViewer
#' @importFrom jsonlite fromJSON
#' @importFrom stringi
#'   stri_replace_all_fixed stri_replace_all_regex stri_opts_regex
#'   stri_split_regex stri_detect_regex stri_startswith_fixed stri_trans_toupper
NULL

utils::globalVariables("tags")

chat_css <- function() {
  "
  /* ---- Layout ---- */
  html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    overflow: hidden;
    box-sizing: border-box;
  }

  .chat-layout {
    display: flex;
    flex-direction: row;
    height: 100%;       /* inherit from body/iframe to avoid 100vh overflow */
    width: 100%;
    overflow: hidden;
    box-sizing: border-box;
  }

  /* ---- Sidebar ---- */
  .chat-sidebar {
    width: 230px;
    min-width: 230px;
    background: #f8f9fa;
    border-right: 1px solid #dee2e6;
    display: flex;
    flex-direction: column;
    padding: 14px 12px;
    gap: 14px;
    overflow-y: auto;
  }

  .sidebar-logo {
    font-size: 14px;
    font-weight: 700;
    color: #2c3e50;
    padding-bottom: 6px;
    border-bottom: 1px solid #dee2e6;
  }

  .sidebar-section { display: flex; flex-direction: column; gap: 4px; }

  .sidebar-label {
    font-size: 11px;
    font-weight: 600;
    color: #868e96;
    text-transform: uppercase;
    letter-spacing: .5px;
    margin-bottom: 2px;
  }

  .sidebar-btn {
    display: flex;
    align-items: center;
    gap: 7px;
    padding: 6px 10px;
    border: 1px solid #dee2e6;
    border-radius: 6px;
    background: white;
    font-size: 13px;
    cursor: pointer;
    color: #495057;
    transition: background .15s;
    text-align: left;
    width: 100%;
  }

  .sidebar-btn:hover { background: #e9ecef; }
  .sidebar-btn.active {
    background: #228be6;
    color: white;
    border-color: #1c7cd6;
  }

  /* Toggle switch */
  .toggle-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 13px;
    color: #495057;
  }

  .toggle-switch {
    position: relative; width: 36px; height: 20px;
    flex-shrink: 0;
  }

  .toggle-switch input { opacity: 0; width: 0; height: 0; }

  .toggle-slider {
    position: absolute; cursor: pointer;
    inset: 0;
    background: #adb5bd;
    border-radius: 20px;
    transition: .2s;
  }

  .toggle-slider::before {
    content: '';
    position: absolute;
    height: 14px; width: 14px;
    left: 3px; bottom: 3px;
    background: white;
    border-radius: 50%;
    transition: .2s;
  }

  .toggle-switch input:checked + .toggle-slider { background: #228be6; }
  .toggle-switch input:checked + .toggle-slider::before {
    transform: translateX(16px);
  }

  /* ---- Chat area ---- */
  .chat-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
  }

  /* Scrollable message region -- sits between sidebar and fixed input */
  .msg-scroll-area {
    flex: 1;
    overflow-y: auto;
    min-height: 0;
  }

  .msg-container {
    padding: 16px 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    scroll-behavior: smooth;
  }

  /* ---- Messages ---- */
  .msg {
    display: flex;
    gap: 10px;
    max-width: 100%;
    animation: msgIn .2s ease;
  }

  @keyframes msgIn {
    from { opacity: 0; transform: translateY(6px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  .msg.user  { flex-direction: row-reverse; }
  .msg.error { flex-direction: row; }

  .msg-avatar {
    width: 30px; height: 30px;
    border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    font-size: 12px;
    flex-shrink: 0;
    font-weight: 700;
  }

  .msg.user .msg-avatar   { background: #e7f5ff; color: #1971c2; }
  .msg.assistant .msg-avatar { background: #f3f0ff; color: #6741d9; }
  .msg.error .msg-avatar { background: #fff5f5; color: #c92a2a; }

  .msg-body {
    max-width: 76%;
    background: white;
    border: 1px solid #dee2e6;
    border-radius: 12px;
    padding: 10px 14px;
    font-size: 14px;
    line-height: 1.6;
    color: #212529;
    word-break: break-word;
  }

  .msg.user .msg-body {
    background: #228be6;
    color: white;
    border-color: #1c7cd6;
    border-bottom-right-radius: 4px;
  }

  .msg.error .msg-body {
    background: #fff5f5;
    color: #c92a2a;
    border-color: #fcc2c2;
  }

  .msg.assistant .msg-body {
    border-bottom-left-radius: 4px;
  }

  /* Code blocks inside messages */
  .msg-body pre {
    background: #f6f8fa;
    border: 1px solid #e1e4e8;
    border-radius: 8px;
    padding: 0;
    overflow: hidden;
    font-size: 13px;
    font-family: 'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', monospace;
    margin: 8px 0;
    position: relative;
    line-height: 1.5;
  }

  .msg.user pre {
    background: rgba(0,0,0,.18);
    border-color: rgba(255,255,255,.2);
  }

  /* code-header: dark bar like GitHub / VS Code */
  .code-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 12px;
    background: #eaeef2;
    border-bottom: 1px solid #e1e4e8;
    border-radius: 8px 8px 0 0;
    gap: 6px;
  }

  .msg.user .code-header {
    background: rgba(0,0,0,.25);
    border-color: rgba(255,255,255,.15);
  }

  .code-lang {
    font-size: 11px;
    font-weight: 600;
    color: #57606a;
    text-transform: uppercase;
    letter-spacing: .4px;
    flex: 1;
  }

  .msg.user .code-lang { color: rgba(255,255,255,.7); }

  /* Button group sitting together on the right */
  .code-btn-group {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .btn-run-code,
  .btn-insert-code {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    font-weight: 500;
    padding: 3px 9px;
    border-radius: 5px;
    border: 1px solid transparent;
    cursor: pointer;
    transition: background .12s, border-color .12s, color .12s;
    line-height: 1.4;
    white-space: nowrap;
  }

  .btn-run-code {
    background: transparent;
    color: #1a73e8;
    border-color: #c8d8f8;
  }
  .btn-run-code:hover {
    background: #1a73e8;
    color: white;
    border-color: #1a73e8;
  }

  .btn-insert-code {
    background: transparent;
    color: #1e8a3e;
    border-color: #b8e6c8;
  }
  .btn-insert-code:hover {
    background: #1e8a3e;
    color: white;
    border-color: #1e8a3e;
  }

  /* Dark bg for user bubble code header buttons */
  .msg.user .btn-run-code,
  .msg.user .btn-insert-code {
    color: rgba(255,255,255,.85);
    border-color: rgba(255,255,255,.3);
  }
  .msg.user .btn-run-code:hover,
  .msg.user .btn-insert-code:hover {
    background: rgba(255,255,255,.25);
    border-color: rgba(255,255,255,.5);
  }

  /* The actual code body */
  .msg-body pre code {
    display: block;
    padding: 12px 14px;
    overflow-x: auto;
    font-size: 13px;
    font-family: inherit;
    line-height: 1.55;
    color: #24292f;
    background: none;
    border: none;
  }

  .msg.user pre code { color: rgba(255,255,255,.92); }

  .msg-body code {
    font-family: 'SFMono-Regular', 'Consolas', 'Liberation Mono', 'Menlo', monospace;
    font-size: 12.5px;
    background: #f0f2f4;
    border-radius: 3px;
    padding: 1px 5px;
    color: #c7254e;
  }

  .msg.user .msg-body code {
    background: rgba(0,0,0,.2);
    color: rgba(255,255,255,.9);
  }

  .msg-body p { margin: 0 0 8px; }
  .msg-body p:last-child { margin-bottom: 0; }
  .msg-body ul, .msg-body ol { margin: 4px 0; padding-left: 20px; }
  .msg-body strong { font-weight: 600; }
  .msg-body em { font-style: italic; }

  /* ---- Thinking indicator ---- */
  .thinking-wrap {
    display: flex;
    gap: 10px;
    padding: 0 20px 10px;
    animation: msgIn .2s ease;
  }

  .thinking-dots {
    display: flex; gap: 4px; align-items: center;
    padding: 10px 14px;
    background: white;
    border: 1px solid #dee2e6;
    border-radius: 12px;
    border-bottom-left-radius: 4px;
  }

  .dot {
    width: 6px; height: 6px;
    background: #868e96;
    border-radius: 50%;
    animation: bounce 1.2s infinite;
  }

  .dot:nth-child(2) { animation-delay: .2s; }
  .dot:nth-child(3) { animation-delay: .4s; }

  @keyframes bounce {
    0%, 80%, 100% { transform: translateY(0); }
    40%           { transform: translateY(-6px); }
  }

  /* ---- Input area ---- */
  .chat-input-wrap {
    display: flex;
    align-items: flex-end;
    gap: 8px;
    padding: 10px 14px;
    border-top: 1px solid #dee2e6;
    background: white;
    flex-shrink: 0;
  }

  #chat_input {
    flex: 1;
    min-height: 42px;
    max-height: 160px;
    padding: 10px 14px;
    border: 1px solid #ced4da;
    border-radius: 8px;
    font-size: 14px;
    font-family: inherit;
    resize: none;
    line-height: 1.5;
    overflow-y: auto;
    outline: none;
    transition: border-color .15s;
    box-sizing: border-box;
  }

  #chat_input:focus { border-color: #228be6; }
  #chat_input:disabled { background: #f8f9fa; color: #868e96; }

  .send-btn {
    width: 42px; height: 42px;
    background: #228be6;
    border: none;
    border-radius: 8px;
    color: white;
    font-size: 16px;
    cursor: pointer;
    display: flex; align-items: center; justify-content: center;
    transition: background .15s;
    flex-shrink: 0;
  }

  .send-btn:hover { background: #1971c2; }
  .send-btn:disabled { background: #adb5bd; cursor: not-allowed; }

  /* ---- Empty state ---- */
  .empty-state {
    text-align: center;
    color: #adb5bd;
    padding: 40px 20px;
    font-size: 14px;
    line-height: 1.8;
  }

  .empty-state-icon { font-size: 36px; margin-bottom: 10px; }
  "
}

# ---------- Inline JavaScript bridge ----------------------------------------

#' Escape a character string for safe embedding in a JS string literal
#'
#' @param x Character vector.
#' @return Character vector with escapes applied.
#' @keywords internal
.js_esc <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x)   # backslash
  x <- gsub('"',     '\\"',     x)   # double quote
  x <- gsub("\n",    "\\n",     x)   # newline
  x <- gsub("\r",    "\\r",     x)   # carriage return
  x <- gsub("\t",    "\\t",     x)   # tab
  x
}

build_inline_js <- function(session) {
  # JS is now in inst/www/chat_panel.js and loaded via includeScript()
  # This function is kept for backward compatibility but no longer used.
  NULL
}

# ---------- Helpers (Shiny UI) -------------------------------------------------

# Custom titleBarButton
.titleBarButton <- function(inputId, label, primary = FALSE,
                             icon = NULL, title = NULL) {
  btn_class <- if (isTRUE(primary)) "btn-primary" else "btn-default"
  attrs <- list(
    id    = inputId,
    class = paste("btn btn-sm action-button", btn_class)
  )
  if (!is.null(title)) attrs$title <- title
  label_content <- if (!is.null(icon)) htmltools::tagList(icon, label) else label
  do.call(htmltools::tags$button, c(attrs, list(label_content)))
}

# ---------- Shiny UI ----------------------------------------------------------

chat_title_bar <- function(title = "LLMcoder Chat Panel") {
  htmltools::tags$div(
    style = "display: flex; align-items: center; justify-content: space-between; padding: 8px 16px; background: #2c3e50; color: white; font-size: 15px; font-weight: 600; flex-shrink: 0;",
    htmltools::tags$span(title),
    htmltools::tags$div(
      style = "display: flex; gap: 8px;",
      htmltools::tags$button(
        id = "btn_done",
        class = "btn btn-sm btn-primary",
        style = "background: #228be6; border: none; color: white; padding: 4px 12px; border-radius: 4px; cursor: pointer;",
        "Done"
      )
    )
  )
}

chat_ui <- function(system_prompt_override) {

  tags <- htmltools::tags
  HTML <- htmltools::HTML

  js_src <- system.file("www/chat_panel.js", package = "llmcoder")
  js_content <- readLines(js_src, warn = FALSE)
  js_content <- paste(js_content, collapse = "\n")

  shiny::fillPage(
    tags$head(
      tags$style(chat_css()),
      tags$script(HTML(js_content))
    ),

    # Title bar
    chat_title_bar(),

    # Main layout: sidebar + chat area
    tags$div(class = "chat-layout",

      # ---- Sidebar (fixed width, left) ----
      tags$div(class = "chat-sidebar",

        tags$div(class = "sidebar-logo",
          tags$i(class = "fa fa-comment-dots", style = "margin-right:6px"),
          "LLMcoder"),

        # Context toggle + file browser
        tags$div(class = "sidebar-section",
          tags$div(class = "sidebar-label", "Context"),

          # Toggle for auto session context
          tags$div(class = "toggle-row",
            tags$span("Session Context"),
            tags$label(class = "toggle-switch",
              tags$input(type = "checkbox", id = "toggle_ctx", checked = NA),
              tags$span(class = "toggle-slider")
            )
          ),

          # File browser for manual context
          tags$div(style = "margin-top: 8px",
            tags$button(id = "btn_browse", class = "action-button sidebar-btn",
              tags$i(class = "fa fa-folder-open", style = "width:16px"),
              "Add File to Context"),
            shiny::uiOutput("context_files_ui")
          )
        ),

        # Style selector
        tags$div(class = "sidebar-section",
          tags$div(class = "sidebar-label", "Prompt Style"),
          tags$select(id = "sel_style", class = "sidebar-btn",
            tags$option(value = "general",   "General Assistant"),
            tags$option(value = "code",     "R Code Helper"),
            tags$option(value = "stats",    "Statistics Advisor"),
            tags$option(value = "research", "Research (Psycho)")
          )
        ),

        tags$div(style = "flex: 1"),

        # Utility buttons
        tags$div(class = "sidebar-section",
          tags$button(id = "btn_clear", class = "action-button sidebar-btn",
            tags$i(class = "fa fa-trash-alt", style = "width:16px"),
            "Clear chat"),
          tags$button(id = "btn_export", class = "action-button sidebar-btn",
            tags$i(class = "fa fa-download", style = "width:16px"),
            "Export transcript")
        )
      ),

      # ---- Main chat area (flex: 1) ----
      tags$div(class = "chat-main",

        # Scrollable message area
        tags$div(class = "msg-scroll-area",
          tags$div(id = "msg_container", class = "msg-container",
            tags$div(id = "empty_state", class = "empty-state",
              tags$div(class = "empty-state-icon", HTML("&#128100;")),
              tags$div(tags$strong("LLMcoder Chat Panel")),
              tags$div("Ask me anything about R, data analysis, ",
                tags$br(), "statistics, or your code.")
            )
          ),

          tags$div(id = "thinking_wrap", class = "thinking-wrap",
            style = "display: none",
            tags$div(class = "thinking-dots",
              tags$div(class = "dot"),
              tags$div(class = "dot"),
              tags$div(class = "dot")
            )
          )
        ),

        # Fixed input bar at bottom
        tags$div(class = "chat-input-wrap",
          tags$textarea(
            id          = "chat_input",
            placeholder = "Type a message... (Ctrl+Enter to send)",
            rows        = 1,
            autofocus   = "autofocus"
          ),
          tags$button(id = "btn_send", class = "send-btn", "Send")
        )
      )
    )
  )
}


# ---------- Server logic ------------------------------------------------------

chat_server <- function(input, output, session,
                       system_prompt_override) {

  rv <- shiny::reactiveValues(
    history       = list(),
    thinking      = FALSE,
    session_ctx   = character(0),
    style         = "general",
    context_files = list()   # stores selected files for context
  )

  build_chat_system_prompt <- function(style, ctx_enabled) {
    base <- switch(style,
      general  = "You are a helpful AI assistant for an R user. Answer clearly, accurately, and concisely. Format code with triple backticks marked `r`.",
      code     = "You are an expert R programmer. Write clean, idiomatic R code using tidyverse where appropriate. Show code in ```r fences and explain briefly.",
      stats    = "You are a statistics and R advisor for a psycholinguistics researcher. Explain concepts clearly, suggest appropriate tests, and provide R code for analysis.",
      research = "You are a research assistant for a psycholinguistics PhD student using R. Help with experimental design, mixed-effects models (lme4/lmerTest), data visualisation (ggplot2), and statistical reporting."
    )

    # Append session context if enabled
    if (ctx_enabled && !is.null(system_prompt_override)) {
      base <- paste0(base, "\n\n[SESSION CONTEXT]\n", system_prompt_override)
    } else if (ctx_enabled && length(rv$session_ctx) > 0) {
      base <- paste0(base, "\n\n[SESSION CONTEXT]\n", rv$session_ctx)
    }

    # Append selected file contents
    if (length(rv$context_files) > 0) {
      file_blocks <- vapply(names(rv$context_files), function(fpath) {
        f <- rv$context_files[[fpath]]
        paste0("[FILE: ", f$name, "]\n```\n", f$content, "\n```")
      }, character(1))
      base <- paste0(base, "\n\n[SELECTED FILES]\n", paste(file_blocks, collapse = "\n\n"))
    }

    base
  }

  shiny::observe({
    shiny::req(input$toggle_ctx)
    if (isTRUE(input$toggle_ctx)) {
      tryCatch({
        rv$session_ctx <- session_context_prompt()
      }, error = function(e) {
        rv$session_ctx <- character(0)
      })
    } else {
      rv$session_ctx <- character(0)
    }
  })

  shiny::observeEvent(input$sel_style, {
    rv$style <- input$sel_style
  })

  shiny::observeEvent(input$btn_clear, {
    rv$history <- list()
    session$sendCustomMessage("clearDone", list())
  })

  shiny::observeEvent(input$btn_export, {
    if (length(rv$history) == 0) return()
    lines <- vapply(rv$history, function(m) {
      paste0(toupper(m[["role"]]), ": ", m[["content"]])
    }, character(1))
    txt <- paste(c("# LLMcoder Chat Transcript", Sys.time(), "", lines), collapse = "\n")
    default_path <- file.path(path.expand("~"),
                              paste0("llmcoder_transcript_",
                                     format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt"))
    path <- tryCatch({
      rstudioapi::selectFile(label = "Save transcript as", path = default_path,
                             filter = "Text files (*.txt)")
    }, error = function(e) default_path)
    if (!is.null(path) && nchar(path) > 0) {
      writeLines(txt, path)
      rstudioapi::showDialog("Export", paste("Transcript saved to:\n", path))
    }
  })


  # ---- Browse and add file to context ----
  shiny::observeEvent(input$btn_browse, {
    path <- tryCatch({
      rstudioapi::selectFile(
        label = "Select file to add to context",
        filter = "All files (*.*)"
      )
    }, error = function(e) NULL)

    if (is.null(path) || !file.exists(path)) return()

    # Avoid duplicates
    if (path %in% names(rv$context_files)) return()

    # Read file content (try UTF-8, fallback to Latin-1)
    content <- tryCatch({
      readLines(path, encoding = "UTF-8", warn = FALSE)
    }, error = function(e) {
      tryCatch({
        readLines(path, encoding = "latin1", warn = FALSE)
      }, error = function(e2) character(0))
    })

    if (length(content) > 0) {
      rv$context_files[[path]] <- list(
        name    = basename(path),
        path    = path,
        content = paste(content, collapse = "\n")
      )
    } else {
      rstudioapi::showDialog("LLMcoder",
        paste("Could not read file:\n", path))
    }
  })


  # ---- Remove file from context ----
  shiny::observeEvent(input$remove_file, {
    req(input$remove_file)
    fname <- input$remove_file
    rv$context_files[[fname]] <- NULL
  })


  # ---- Render selected files list in sidebar ----
  output$context_files_ui <- shiny::renderUI({
    files <- rv$context_files
    if (length(files) == 0) {
      return(tags$div(style = "font-size: 11px; color: #868e96; padding: 4px 0;",
                      "No files added"))
    }

    tag_list <- lapply(names(files), function(fpath) {
      f <- files[[fpath]]
      tags$div(
        style = "display: flex; align-items: center; justify-content: space-between;
                padding: 4px 6px; margin-bottom: 3px;
                background: #f8f9fa; border-radius: 4px; font-size: 12px;",
        tags$span(
          style = "overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 140px;",
          tags$i(class = "fa fa-file-code", style = "margin-right: 4px; color: #495057"),
          f$name
        ),
        tags$button(
          type  = "button",
          class = "btn-remove-file",
          onclick = sprintf("Shiny.setInputValue('remove_file', '%s')", fpath),
          style  = "background: none; border: none; color: #e74c3c; cursor: pointer; font-size: 14px; padding: 0 4px;",
          "x"
        )
      )
    })
    do.call(tags$div, tag_list)
  })

  # Make context_files_ui available to UI
  shiny::outputOptions(output, "context_files_ui", suspendWhenHidden = FALSE)


  shiny::observeEvent(input$doChat, {
    text <- input$doChat
    if (!nzchar(trimws(text))) return()

    ctx_enabled <- isTRUE(input$toggle_ctx)
    sys_prompt  <- build_chat_system_prompt(rv$style, ctx_enabled)

    rv$history  <- c(rv$history, list(list(role = "user", content = text)))
    rv$thinking <- TRUE

    msgs <- c(list(list(role = "system", content = sys_prompt)), rv$history)

    resp <- tryCatch({
      message("[llmcoder] Calling LLM with text: ", substr(text, 1, 80))
      safe_call_llm_history(msgs)
    }, error = function(e) {
      message("[llmcoder] LLM error: ", conditionMessage(e))
      list(error = conditionMessage(e))
    })

    rv$thinking <- FALSE
    session$sendCustomMessage("thinkingDone", list())

    if (is.list(resp) && !is.null(resp$error)) {
      session$sendCustomMessage("appendMsg", list(
        role = "error",
        html = paste0("<p>Error: ", escape_html(resp$error), "</p>")
      ))
      session$sendCustomMessage("inputEnabled", list(enabled = TRUE))
      return()
    }

    rv$history <- c(rv$history, list(list(role = "assistant", content = resp)))
    message("[llmcoder] resp type: ", typeof(resp),
            " is_list:", is.list(resp),
            " is_fn:", is.function(resp))
    html <- render_markdown_html(resp)

    session$sendCustomMessage("appendMsg", list(
      role  = "assistant",
      html  = html
    ))
    session$sendCustomMessage("inputEnabled", list(enabled = TRUE))
  })

  # ---- Run code in console ----
  shiny::observeEvent(input$doRunCode, {
    code <- input$doRunCode
    if (!nzchar(trimws(code))) return()
    tryCatch({
      rstudioapi::sendToConsole(code, execute = TRUE, focus = FALSE)
    }, error = function(e) {
      rstudioapi::showDialog("LLMcoder", paste("Could not send to console:", e$message))
    })
  })

  # ---- Insert code into script ----
  shiny::observeEvent(input$doInsertCode, {
    code <- input$doInsertCode
    if (!nzchar(trimws(code))) return()
    tryCatch({

      rstudioapi::insertText(code)
    }, error = function(e) {

      tryCatch({
        rstudioapi::sendToConsole(code, execute = FALSE, focus = FALSE)
        rstudioapi::showDialog("LLMcoder", "No active document. Code sent to console (not executed).")
      }, error = function(e2) {
        rstudioapi::showDialog("LLMcoder", paste("Could not insert code:", e$message))
      })
    })
  })

  shiny::observeEvent(input$btn_done, {
    shiny::stopApp()
  })
}


# ---------- Markdown renderer -------------------------------------------------

# function triggers "cannot coerce type 'closure'" in R's C internals.
# All markdown rendering uses stringi (ICU regex) with manual replacement logic,
# because stri_replace_all_regex() does NOT support function replacement.

escape_html <- function(s) {
  if (!is.character(s) || length(s) == 0) return("")


  s <- gsub("&", "&amp;",  s, fixed = TRUE)
  s <- gsub("<", "&lt;",   s, fixed = TRUE)
  s <- gsub(">", "&gt;",   s, fixed = TRUE)
  s
}

# Workaround: stri_replace_all() doesn't support function replacement.
# Use stri_match_all + manual string reconstruction (right-to-left).
# New stringi API: pass regex options via ... to regex(pattern, ...)
replace_all_regex_fn <- function(str_vec, pattern, repl_fn, ...) {
  vapply(seq_along(str_vec), function(i) {
    s <- str_vec[i]
    matches <- stri_match_all(s, ..., regex = pattern)[[1]]
    if (is.na(matches[1, 1])) return(s)
    n <- nrow(matches)
    positions <- stri_locate_all(s, ..., regex = pattern)[[1]]
    result <- ""
    prev_end <- nchar(s) + 1L
    for (j in rev(seq_len(n))) {
      m_start <- positions[j, 1]
      m_end   <- positions[j, 2]
      repl <- repl_fn(c(matches[j, 1], matches[j, 2:ncol(matches)]))
      result <- paste0(
        if (m_end + 1L <= prev_end - 1L)
          stri_sub(s, m_end + 1L, prev_end - 1L)
        else "",
        repl,
        result
      )
      prev_end <- m_start
    }
    paste0(stri_sub(s, 1L, prev_end - 1L), result)
  }, character(1), USE.NAMES = FALSE)
}

render_markdown_html <- function(text) {
  if (!is.character(text) || length(text) == 0) {
    text <- if (is.function(text)) {
      "[LLM returned a function object -- possible API misconfiguration]"
    } else {
      as.character(text)
    }
  }
  rendered <- as.character(text)[1]

  # ---- Code fences ----

  lines <- unlist(strsplit(rendered, "\n"))
  in_code_block <- FALSE
  code_lang <- ""
  code_lines <- character(0)
  output_parts <- character(0)

  for (i in seq_along(lines)) {
    line <- lines[i]


    if (grepl("^```[A-Za-z0-9_]*$", line)) {
      if (!in_code_block) {

        in_code_block <- TRUE
        code_lang <- gsub("`", "", line)
        if (code_lang == "") code_lang <- "text"
        next
      } else {

        in_code_block <- FALSE
        inner <- paste(code_lines, collapse = "\n")
        code_lines <- character(0)


        escaped <- escape_html(inner)
        label <- if (code_lang == "r" || code_lang == "R") "R" else toupper(code_lang)

        if (code_lang == "r" || code_lang == "R") {
          enc <- URLencode(inner, reserved = TRUE)
          run_icon <- "<svg width='11' height='11' viewBox='0 0 16 16' fill='currentColor' style='flex-shrink:0'><path d='M3 2.5a.5.5 0 0 1 .765-.424l10 5.5a.5.5 0 0 1 0 .848l-10 5.5A.5.5 0 0 1 3 13.5v-11z'/></svg>"
          insert_icon <- "<svg width='11' height='11' viewBox='0 0 16 16' fill='currentColor' style='flex-shrink:0'><path d='M8 1a.5.5 0 0 1 .5.5V11h2.793l-2.147-2.146a.5.5 0 0 1 .708-.708l3 3a.5.5 0 0 1 0 .708l-3 3a.5.5 0 0 1-.708-.708L11.293 12H8.5v2.5a.5.5 0 0 1-1 0V12H4.707l2.147 2.146a.5.5 0 0 1-.708.708l-3-3a.5.5 0 0 1 0-.708l3-3a.5.5 0 0 1 .708.708L4.207 12H7.5V1.5A.5.5 0 0 1 8 1z'/></svg>"
          run_btn    <- paste0("<button class='btn-run-code' data-code='", enc, "'>", run_icon, " Run</button>")
          insert_btn <- paste0("<button class='btn-insert-code' data-code='", enc, "'>", insert_icon, " Insert</button>")
          buttons <- paste0("<div class='code-btn-group'>", run_btn, insert_btn, "</div>")
        } else {
          buttons <- ""
        }

        pre_block <- paste0("<pre><div class='code-header'><span class='code-lang'>",
                            label, "</span>", buttons,
                            "</div><code>", escaped, "</code></pre>")
        # Surround with blank lines so the paragraph splitter keeps <pre> isolated
        output_parts <- c(output_parts, "", pre_block, "")
        next
      }
    }

    if (in_code_block) {
      code_lines <- c(code_lines, line)
    } else {
      output_parts <- c(output_parts, line)
    }
  }


  rendered <- paste(output_parts, collapse = "\n")

  # ---- Process Markdown inline formatting ----

  blocks <- unlist(strsplit(rendered, "\n\n+"))
  blocks <- blocks[nchar(gsub("\\s", "", blocks)) > 0]

  render_block <- function(block) {

    if (grepl("^<pre>", block)) {
      return(block)
    }

    if (grepl("^### ", block, perl = TRUE)) {
      title <- substring(block, 5)
      return(paste0("<h4>", title, "</h4>"))
    }
    if (grepl("^## ", block, perl = TRUE)) {
      title <- substring(block, 4)
      return(paste0("<h3>", title, "</h3>"))
    }
    if (grepl("^# ", block, perl = TRUE)) {
      title <- substring(block, 3)
      return(paste0("<h2>", title, "</h2>"))
    }

    if (grepl("^[-*] ", block, perl = TRUE)) {
      items <- unlist(strsplit(block, "\n"))
      items <- sapply(items, function(item) {
        content <- sub("^[-*] ", "", item, perl = TRUE)
        paste0("<li>", content, "</li>")
      })
      return(paste0("<ul>\n", paste0(items, collapse = "\n"), "\n</ul>"))
    }

    block <- escape_html(block)

    m <- gregexpr("`[^`]+`", block, perl = TRUE)
    if (m[[1]][1] != -1) {
      matches <- regmatches(block, m)[[1]]
      for (j in rev(seq_along(matches))) {
        code <- substring(matches[j], 2, nchar(matches[j]) - 1)
        pos <- m[[1]][j]
        len <- attr(m[[1]], "match.length")[j]
        block <- paste0(
          substr(block, 1, pos - 1),
          paste0("<code>", code, "</code>"),
          substr(block, pos + len, nchar(block))
        )
      }
    }

    m <- gregexpr("\\*\\*([^*]+)\\*\\*", block, perl = TRUE)
    if (m[[1]][1] != -1) {
      matches <- regmatches(block, m)[[1]]
      for (j in rev(seq_along(matches))) {
        content <- gsub("\\*\\*", "", matches[j], fixed = TRUE)
        pos <- m[[1]][j]
        len <- attr(m[[1]], "match.length")[j]
        block <- paste0(
          substr(block, 1, pos - 1),
          paste0("<strong>", content, "</strong>"),
          substr(block, pos + len, nchar(block))
        )
      }
    }

    m <- gregexpr("(?<![*])\\*([^*]+)\\*(?![*])", block, perl = TRUE)
    if (m[[1]][1] != -1) {
      matches <- regmatches(block, m)[[1]]
      for (j in rev(seq_along(matches))) {
        content <- gsub("\\*", "", matches[j], fixed = TRUE)
        pos <- m[[1]][j]
        len <- attr(m[[1]], "match.length")[j]
        block <- paste0(
          substr(block, 1, pos - 1),
          paste0("<em>", content, "</em>"),
          substr(block, pos + len, nchar(block))
        )
      }
    }
    paste0("<p>", block, "</p>")
  }

  rendered <- paste(sapply(blocks, render_block), collapse = "\n")

  htmltools::HTML(rendered)
}



# ---------- JS <-> R bridge handlers -----------------------------------------

chat_js_handlers <- function(session) {
  invisible(NULL)
}


# ---------- Public entry point -------------------------------------------------

#' @export
addin_chat_panel <- function(system_prompt_override = NULL) {
  if (!requireNamespace("rstudioapi", quietly = TRUE) ||
      !rstudioapi::isAvailable()) {
    stop("addin_chat_panel() must be run from within RStudio.", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The 'jsonlite' package is required for addin_chat_panel(). ",
         "Install it with: install.packages('jsonlite')", call. = FALSE)
  }
  chat_gadget(system_prompt_override = system_prompt_override)
}


# ---------- Gadget factory ----------------------------------------------------

chat_gadget <- function(system_prompt_override = NULL) {
  ui <- chat_ui(system_prompt_override)
  server <- function(input, output, session) {
    chat_server(input, output, session, system_prompt_override)
  }
  viewer <- shiny::dialogViewer(
    "LLMcoder Chat Panel",
    width  = 1400,
    height = 950
  )
  shiny::runGadget(ui, server, viewer = viewer)
}


# ---------- LLM multi-turn API -----------------------------------------------

safe_call_llm_history <- function(messages, system_prompt_override = NULL) {
  tryCatch(
    call_llm_history(messages, system_prompt_override),
    error = function(e) list(error = conditionMessage(e))
  )
}
