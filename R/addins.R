# ============================================================
#  llmcoder — RStudio addin entry points
# ============================================================

#' Generate R code from a comment (silent insert)
#'
#' Places the cursor on a line beginning with `#`, then triggers this addin
#' (default shortcut: `Ctrl+Shift+G` on Windows/Linux, `Cmd+Shift+G` on macOS).
#' The LLM reads the comment text and the surrounding code context, then inserts
#' the generated R code on the line immediately below the comment.
#'
#' @details
#' The addin extracts the text of the comment at the cursor position and up to
#' `getOption("llmcoder.context_lines", 40L)` lines of preceding code as
#' context.  The provider, model, and API key are taken from options set by
#' [llmcoder_setup()] or the **LLMcoder Settings** addin.
#'
#' No dialog is shown; code is inserted immediately.  Use
#' [addin_generate_with_preview()] if you prefer to review the output first.
#'
#' @return Invisible `NULL` (called for side-effects).
#' @seealso [addin_generate_with_preview()], [llmcoder_setup()]
#' @export
addin_generate_from_comment <- function() {

  ctx <- safe_get_ctx(); if (is.null(ctx)) return(invisible(NULL))

  info <- tryCatch(extract_comment_at_cursor(ctx), error = function(e) {
    rstudioapi::showDialog("LLMcoder", conditionMessage(e)); NULL
  })
  if (is.null(info)) return(invisible(NULL))

  n_ctx <- getOption("llmcoder.context_lines", 40L)
  context_code <- gather_context(ctx, info$row, n = n_ctx)

  notify(paste0('Generating: "', info$comment, '" ...'))

  code <- safe_call_llm(
    prompt        = paste0("Write R code that: ", info$comment),
    system_prompt = build_system_prompt(),
    context       = context_code
  )
  if (is.null(code)) return(invisible(NULL))

  insert_after_row(clean_code_output(code), info$row, indent = info$indent)
  notify("Done.")
  invisible(NULL)
}


#' Generate R code with an editable preview dialog
#'
#' Same as [addin_generate_from_comment()] but opens a Shiny gadget so you can
#' review and optionally edit the generated code before it is inserted into the
#' editor.  Recommended shortcut: `Ctrl+Shift+P` / `Cmd+Shift+P`.
#'
#' @details
#' The preview dialog shows the generated code in an editable text area.
#' Click **Insert** to place it in the editor, or close the dialog to discard
#' the result.
#'
#' @return Invisible `NULL` (called for side-effects).
#' @seealso [addin_generate_from_comment()], [llmcoder_setup()]
#' @export
addin_generate_with_preview <- function() {

  ctx <- safe_get_ctx(); if (is.null(ctx)) return(invisible(NULL))

  info <- tryCatch(extract_comment_at_cursor(ctx), error = function(e) {
    rstudioapi::showDialog("LLMcoder", conditionMessage(e)); NULL
  })
  if (is.null(info)) return(invisible(NULL))

  n_ctx <- getOption("llmcoder.context_lines", 40L)
  context_code <- gather_context(ctx, info$row, n = n_ctx)

  notify(paste0('Calling LLM for: "', info$comment, '" ...'))

  code <- safe_call_llm(
    prompt        = paste0("Write R code that: ", info$comment),
    system_prompt = build_system_prompt(),
    context       = context_code
  )
  if (is.null(code)) return(invisible(NULL))

  preview_gadget(
    comment = info$comment,
    code    = clean_code_output(code),
    row     = info$row,
    indent  = info$indent,
    ctx_id  = ctx$id
  )
  invisible(NULL)
}


#' Fix the last console error automatically
#'
#' After running code that produces an error in the R console, trigger this
#' addin (recommended shortcut: `Ctrl+Shift+F` / `Cmd+Shift+F`).
#'
#' @details
#' The addin attempts to recover the most recent error message using several
#' strategies, in order of priority:
#'
#' \enumerate{
#'   \item The `rlang` last-error store (`rlang::last_error()`), which captures
#'         errors thrown by \pkg{rlang}-aware packages and the tidyverse.
#'   \item Base R's `.Last.error` binding (set whenever an unhandled condition
#'         reaches the top level).
#'   \item The `.Last.error.trace` character vector written by some versions of
#'         \pkg{rlang}.
#' }
#'
#' The complete source file currently open in the editor is also sent to the LLM
#' as context.  The LLM returns the entire corrected file, with changed lines
#' annotated as `# FIX: <reason>`.  A diff-style preview dialog lets you review
#' and edit the fix before applying it.
#'
#' **Workflow**
#' 1. Run code — error appears in console.
#' 2. Trigger this addin.
#' 3. Review the fix in the preview dialog → click **Apply Fix**.
#'
#' If no recent error is detected, a dialog explains the possible reasons and
#' suggests using [addin_fix_selected_error()] instead.
#'
#' @return Invisible `NULL` (called for side-effects).
#' @seealso [addin_fix_selected_error()], [llmcoder_setup()]
#' @export
addin_fix_console_error <- function() {

  # ---- 1. Grab the last error — try multiple sources -------------------
  last_err <- .collect_last_error()

  if (is.null(last_err) || nchar(trimws(last_err)) == 0) {
    rstudioapi::showDialog(
      "LLMcoder \u2014 Fix Error",
      paste0(
        "No recent error found.\n\n",
        "Possible reasons:\n",
        "  \u2022 The code was sourced inside a tryCatch() that swallowed the error.\n",
        "  \u2022 You are using a session where .Last.error is not set.\n\n",
        "Alternative: copy the error text from the console, paste it somewhere\n",
        "in the editor, select it, and use 'Fix Selected Error Text' instead."
      )
    )
    return(invisible(NULL))
  }

  # ---- 2. Get the current source file ----------------------------------
  ctx <- safe_get_ctx(); if (is.null(ctx)) return(invisible(NULL))

  source_code <- paste(ctx$contents, collapse = "\n")

  if (nchar(trimws(source_code)) == 0) {
    rstudioapi::showDialog(
      "LLMcoder \u2014 Fix Error",
      "The current editor appears to be empty.\nOpen the file that caused the error."
    )
    return(invisible(NULL))
  }

  # ---- 3. Call LLM -----------------------------------------------------
  notify(paste0("Diagnosing error: ", substr(last_err, 1, 80), " ..."))

  prompt <- paste0(
    "ERROR MESSAGE:\n", last_err,
    "\n\nSOURCE CODE:\n```r\n", source_code, "\n```\n\n",
    "Fix the error. Return the complete corrected source."
  )

  fixed_code <- safe_call_llm(
    prompt        = prompt,
    system_prompt = build_fix_prompt(),
    context       = NULL
  )
  if (is.null(fixed_code)) return(invisible(NULL))

  # ---- 4. Show preview + apply -----------------------------------------
  fix_preview_gadget(
    error_msg  = last_err,
    original   = source_code,
    fixed      = clean_code_output(fixed_code),
    ctx        = ctx
  )

  invisible(NULL)
}


#' Fix an error by selecting its text
#'
#' Select the error message text in the editor (or paste it into a temporary
#' comment), then trigger this addin.  The addin pairs the selected text with
#' the complete source file currently open in the editor and asks the LLM for a
#' fix, displaying the result in a review dialog.
#'
#' @details
#' This addin is the recommended fallback when [addin_fix_console_error()] does
#' not detect an error automatically (e.g., because the error occurred inside a
#' `tryCatch()` block or in a separate R process).
#'
#' **Workflow**
#' 1. Copy the error message from the console.
#' 2. Paste it anywhere in the source file, or simply select it in the console
#'    output if your terminal supports that.
#' 3. Select the error text in the editor.
#' 4. Trigger this addin.
#' 5. Review and apply the suggested fix.
#'
#' @return Invisible `NULL` (called for side-effects).
#' @seealso [addin_fix_console_error()], [llmcoder_setup()]
#' @export
addin_fix_selected_error <- function() {

  ctx <- safe_get_ctx(); if (is.null(ctx)) return(invisible(NULL))
  sel <- ctx$selection[[1]]$text

  if (nchar(trimws(sel)) == 0) {
    rstudioapi::showDialog(
      "LLMcoder \u2014 Fix Selected Error",
      "Select the error message text first, then trigger this addin."
    )
    return(invisible(NULL))
  }

  source_code <- paste(ctx$contents, collapse = "\n")

  notify("Diagnosing selected error ...")

  prompt <- paste0(
    "ERROR MESSAGE:\n", sel,
    "\n\nSOURCE CODE:\n```r\n", source_code, "\n```\n\n",
    "Fix the error. Return the complete corrected source."
  )

  fixed_code <- safe_call_llm(
    prompt        = prompt,
    system_prompt = build_fix_prompt(),
    context       = NULL
  )
  if (is.null(fixed_code)) return(invisible(NULL))

  fix_preview_gadget(
    error_msg = sel,
    original  = source_code,
    fixed     = clean_code_output(fixed_code),
    ctx       = ctx
  )
  invisible(NULL)
}


#' Explain selected R code as inline comments
#'
#' Select a block of R code in the editor, then trigger this addin
#' (recommended shortcut: `Ctrl+Shift+E` / `Cmd+Shift+E`).  An explanation is
#' inserted as `#` comment lines immediately **above** the selected code block.
#'
#' @details
#' The LLM receives the selected code and is instructed to produce a concise,
#' human-readable explanation — focusing on *what* the code does and *why*,
#' not on basic R syntax.  Every output line is prefixed with `# ` so the
#' explanation is valid R that can be left in the source file.
#'
#' @return Invisible `NULL` (called for side-effects).
#' @seealso [addin_generate_from_comment()], [llmcoder_setup()]
#' @export
addin_explain_code <- function() {

  ctx <- safe_get_ctx(); if (is.null(ctx)) return(invisible(NULL))
  sel <- ctx$selection[[1]]

  if (nchar(trimws(sel$text)) == 0) {
    rstudioapi::showDialog("LLMcoder",
      "No code selected. Select the R code you want explained, then try again.")
    return(invisible(NULL))
  }

  notify("Generating explanation ...")

  explanation <- safe_call_llm(
    prompt        = paste0("Explain this R code:\n```r\n", sel$text, "\n```"),
    system_prompt = build_explain_prompt(),
    context       = NULL
  )
  if (is.null(explanation)) return(invisible(NULL))

  # Ensure every line starts with #
  lines <- stringr::str_split(explanation, "\n")[[1]]
  lines <- ifelse(stringr::str_starts(lines, "#"), lines, paste0("# ", lines))
  comment_block <- paste(lines, collapse = "\n")

  rstudioapi::insertText(
    location = rstudioapi::document_position(sel$range$start[["row"]], 1L),
    text     = paste0(comment_block, "\n"),
    id       = ctx$id
  )
  notify("Explanation inserted.")
  invisible(NULL)
}


#' Open the LLMcoder settings dialog
#'
#' Launches an interactive Shiny gadget that lets you configure the LLM
#' provider, model, API key, Ollama URL (for local models), custom base URL
#' (for LM Studio / vLLM / llama.cpp), and context-window size.  Settings can
#' optionally be persisted to `~/.Rprofile` so they survive R restarts.
#'
#' @return Invisible `NULL` (called for side-effects).
#' @seealso [llmcoder_setup()], [llmcoder_config()]
#' @export
addin_settings <- function() settings_gadget()


# ---------- Internal helpers --------------------------------------------------

#' Strip markdown code fences from LLM output
#'
#' Strips common markdown code fences from LLM output so the raw code can be
#' inserted into the editor.
#'
#' @param code Character string returned by an LLM, possibly wrapped in
#'   ` ```r` code fences.
#' @return Character string with fences removed.  If no fences are found, the
#'   input is returned as-is.
#' @examples
#' \dontrun{
#' raw <- "\n```r\nx <- mean(1:10)\nprint(x)\n```\n"
#' clean_code_output(raw)
#' clean_code_output("no fences here")
#' }
#' @keywords internal
clean_code_output <- function(code) {
  code <- stringr::str_trim(code)
  code <- stringr::str_replace(code, "^```[rR]?\\s*\n?", "")
  code <- stringr::str_replace(code, "\n?```\\s*$", "")
  stringr::str_trim(code)
}

#' Safely obtain the active editor context
#' @keywords internal
safe_get_ctx <- function() {
  tryCatch(get_editor_ctx(), error = function(e) {
    rstudioapi::showDialog("LLMcoder Error", conditionMessage(e))
    NULL
  })
}

#' Safely call the LLM, catching API errors
#' @keywords internal
safe_call_llm <- function(prompt, system_prompt, context) {
  tryCatch(
    call_llm(prompt = prompt, system_prompt = system_prompt, context = context),
    error = function(e) {
      rstudioapi::showDialog("LLMcoder API Error", conditionMessage(e))
      NULL
    }
  )
}

#' Collect the most recent R error message using multiple strategies
#'
#' Tries, in order: rlang::last_error(), .Last.error (base R),
#' .Last.error condition message.
#' Returns NULL if nothing is found.
#' @keywords internal
.collect_last_error <- function() {

  # Strategy 1: rlang last error (most reliable for tidyverse code)
  err <- tryCatch({
    e <- rlang::last_error()
    if (!is.null(e)) {
      paste0(
        conditionMessage(e),
        if (!is.null(e$trace)) paste0("\n\nTraceback:\n", format(e$trace)) else ""
      )
    } else {
      NULL
    }
  }, error = function(e2) NULL)

  if (!is.null(err) && nchar(trimws(err)) > 0) return(err)

  # Strategy 2: base R .Last.error as character
  # Use get() to avoid R CMD check "no visible binding" note
  last_err_obj <- tryCatch(get(".Last.error", envir = baseenv()),
                            error = function(e) NULL)

  err <- tryCatch(as.character(last_err_obj), error = function(e) NULL)
  if (!is.null(err) && nchar(trimws(err)) > 0) return(err)

  # Strategy 3: conditionMessage on .Last.error
  err <- tryCatch(conditionMessage(last_err_obj), error = function(e) NULL)
  if (!is.null(err) && nchar(trimws(err)) > 0) return(err)

  NULL
}
