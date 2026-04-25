# ============================================================
#  llmcoder — RStudio editor utilities
# ============================================================

#' Get the active source editor context
#'
#' Wraps [rstudioapi::getSourceEditorContext()] with a check that RStudio is
#' available.  Called by all addin entry points before any other operation.
#'
#' @return An `rstudio_editor_context` object (a list returned by
#'   [rstudioapi::getSourceEditorContext()]).
#' @keywords internal
get_editor_ctx <- function() {
  if (!rstudioapi::isAvailable()) {
    stop("This addin requires RStudio.", call. = FALSE)
  }
  rstudioapi::getSourceEditorContext()
}


#' Extract the comment text at the current cursor position
#'
#' Reads the line at the cursor position from the active editor context and
#' returns its components.  Throws an informative error if the cursor is not
#' positioned on a comment line (i.e., a line starting with `#`, possibly
#' preceded by whitespace).
#'
#' @param ctx An `rstudio_editor_context` object from
#'   [rstudioapi::getSourceEditorContext()].
#'
#' @return A named list with four components:
#' \describe{
#'   \item{`comment`}{Character.  The comment text with the leading `#`
#'     character(s) and optional space stripped.}
#'   \item{`row`}{Integer.  1-based row index of the comment line in the
#'     document.}
#'   \item{`full_line`}{Character.  The raw full-line text as it appears in
#'     the editor.}
#'   \item{`indent`}{Character.  The leading whitespace of the line
#'     (used to preserve indentation when inserting generated code).}
#' }
#'
#' @keywords internal
extract_comment_at_cursor <- function(ctx) {
  row      <- ctx$selection[[1]]$range$start[["row"]]
  lines    <- ctx$contents
  line_txt <- lines[[row]]

  # Must be a comment line (possibly with leading whitespace)
  if (!stringr::str_detect(line_txt, "^\\s*#")) {
    stop(
      "Cursor is not on a comment line.\n",
      "Place your cursor on a line starting with # and try again.",
      call. = FALSE
    )
  }

  # Strip leading whitespace + the # character(s) and optional space
  comment_text <- stringr::str_replace(line_txt, "^\\s*#+\\s?", "")

  list(
    comment   = comment_text,
    row       = row,
    full_line = line_txt,
    indent    = stringr::str_extract(line_txt, "^\\s*")
  )
}


#' Collect N lines of surrounding code above the cursor
#'
#' Returns a character string containing the `n` lines of source code
#' immediately above the comment line, joined by newlines.  This is sent to the
#' LLM as context so that it can infer variable names, existing code style, and
#' already-loaded packages.
#'
#' @param ctx  An `rstudio_editor_context` object.
#' @param row  Integer.  1-based row of the comment line (context is taken from
#'   rows `max(1, row - n)` to `row - 1`).
#' @param n    Integer.  Maximum number of context lines (default `30`).
#'
#' @return A single character string (may be `""` if `row == 1`).
#' @keywords internal
gather_context <- function(ctx, row, n = 30) {
  lines     <- ctx$contents
  start_row <- max(1L, row - n)
  end_row   <- max(1L, row - 1L)

  if (start_row > end_row) return("")

  paste(lines[start_row:end_row], collapse = "\n")
}


#' Insert text immediately after a given row in the editor
#'
#' Inserts one or more lines of text at the beginning of the row that follows
#' `row` in the currently active source editor.  Each line is prepended with
#' `indent` to match the indentation level of the originating comment.
#'
#' @param text   Character.  Code to insert; may contain newlines.
#' @param row    Integer.  1-based row *after* which the text is inserted.
#' @param indent Character.  Leading whitespace prepended to every inserted
#'   line (default `""`).
#'
#' @return Invisible `NULL` (called for side-effects).
#' @keywords internal
insert_after_row <- function(text, row, indent = "") {
  # Normalise: strip trailing blank lines
  text <- stringr::str_trim(text, side = "right")

  # Indent each line to match the comment
  indented <- paste(
    paste0(indent, stringr::str_split(text, "\n")[[1]]),
    collapse = "\n"
  )

  # Insert at the beginning of the next line
  insert_pos <- rstudioapi::document_position(row + 1L, 1L)

  rstudioapi::insertText(
    location = insert_pos,
    text     = paste0(indented, "\n"),
    id       = rstudioapi::getSourceEditorContext()$id
  )
}


#' Emit a status message to the R console
#'
#' Prefixes the message with `[llmcoder] ` so users can distinguish addin
#' output from their own code output.
#'
#' @param msg Character.  The message text.
#' @return Invisible `NULL`.
#' @keywords internal
notify <- function(msg) {
  message("[llmcoder] ", msg)
}
