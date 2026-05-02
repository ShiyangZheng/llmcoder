# ============================================================
#  llmcoder — Session Context collection
# ============================================================

#' @importFrom utils getFromNamespace
NULL

#' Capture a human-readable report of the current R session state
#'
#' @description
#' `session_context_report()` collects and formats the following information
#' from the current R session:
#' \itemize{
#'   \item R version and operating system.
#'   \item Loaded add-on packages (non-base).
#'   \item Global environment objects grouped by class.
#'   \item Contents of the active source editor (via \pkg{rstudioapi}).
#'   \item Console command history (via \pkg{rstudioapi}; falls back to
#'         `~/.Rhistory`).
#' }
#'
#' This report is primarily used internally to populate the system prompt
#' sent to the LLM in the [addin_chat_panel()] gadget, so the model has
#' full awareness of the analyst's working environment.
#'
#' @param max_objs   Maximum number of global objects to list per class group
#'                   (default 20).
#' @param max_hist   Maximum number of console history lines to include
#'                   (default 30).
#' @param quiet      If `TRUE`, suppress the `message()` emitted when
#'                   RStudio API is unavailable (default `FALSE`).
#' @return Character string. A multi-section report ready to embed in a
#'   system prompt.
#'
#' @examples
#' \dontrun{
#' report <- session_context_report()
#' cat(report)
#' }
#'
#' @export
session_context_report <- function(max_objs = 20L, max_hist = 30L,
                                   quiet = FALSE) {
  sections <- character(0)

  # ---- 1. R version + OS -------------------------------------------------
  sections <- c(sections, "## R Session Info",
    paste0("R ", R.version.string, " (", R.version$platform, ")"))

  # ---- 2. Loaded packages ------------------------------------------------
  pkgs <- sort(setdiff(.packages(), c("datasets", "utils", "grDevices",
                                      "graphics", "stats", "methods", "base")))
  if (length(pkgs)) {
    sections <- c(sections, "## Loaded Packages",
                  paste0("- ", pkgs, collapse = "\n"))
  } else {
    sections <- c(sections, "## Loaded Packages", "(none)")
  }

  # ---- 3. Global environment objects ------------------------------------
  objs <- ls(envir = .GlobalEnv, all.names = FALSE)
  if (length(objs) > 0) {
    objs_head <- if (length(objs) > max_objs) {
      c(utils::head(objs, max_objs), paste0("... and ", length(objs) - max_objs,
                                     " more (truncated)"))
    } else {
      objs
    }
    sections <- c(sections, "## Global Objects",
                  paste0("- `", objs_head, "`", collapse = "\n"))
  } else {
    sections <- c(sections, "## Global Objects", "(empty)")
  }

  # ---- 4. Source editor contents ----------------------------------------
  if (rstudioapi::isAvailable()) {
    src <- tryCatch({
      ctx <- rstudioapi::getSourceEditorContext()
      if (length(ctx$contents) && nchar(trimws(paste(ctx$contents, collapse = ""))) > 0) {
        paste0("File: ", ctx$path, "\n",
               paste(ctx$contents, collapse = "\n"))
      } else {
        "(no active file)"
      }
    }, error = function(e) "(unavailable)")

    sections <- c(sections, "## Source Editor", src)
  } else {
    if (!quiet) message("rstudioapi not available for source context.")
    sections <- c(sections, "## Source Editor", "(not available)")
  }

  # ---- 5. Console history -----------------------------------------------
  hist_lines <- .get_console_history(max_hist)
  if (length(hist_lines)) {
    sections <- c(sections, "## Console History (recent commands)",
                  paste0("> ", hist_lines, collapse = "\n"))
  } else {
    sections <- c(sections, "## Console History", "(no history available)")
  }

  paste(sections, collapse = "\n\n")
}


#' Build a session-context system-prompt block
#'
#' Convenience wrapper around [session_context_report()] that wraps the report
#' in a descriptive header so the LLM can distinguish it from user content.
#'
#' @param ...  Passed to [session_context_report()].
#' @return Character string suitable for prepending to a system prompt.
#'
#' @examples
#' \dontrun{
#' ctx_prompt <- session_context_prompt()
#' }
#'
#' @export
session_context_prompt <- function(...) {
  paste0(
    "Below is the current R session state. Use this context to give ",
    "accurate, environment-aware responses:\n\n",
    session_context_report(...)
  )
}


# ---------- Helpers -----------------------------------------------------------

#' Console history from rstudioapi with ~/.Rhistory fallback
#' @keywords internal
.get_console_history <- function(max_hist = 30L) {
  # Strategy 1: rstudioapi
  if (rstudioapi::isAvailable()) {
    tryCatch({
      f <- getFromNamespace("getConsoleHistory", "rstudioapi")
      h <- f()
      return(utils::tail(h, max_hist))
    }, error = function(e) NULL)
  }

  # Strategy 2: ~/.Rhistory
  rh <- path.expand("~/.Rhistory")
  if (file.exists(rh)) {
    tryCatch({
      lines <- readLines(rh, warn = FALSE)
      lines <- lines[nchar(trimws(lines)) > 0]
      return(utils::tail(lines, max_hist))
    }, error = function(e) NULL)
  }

  character(0)
}
