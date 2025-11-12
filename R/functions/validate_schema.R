#' Validate a data frame against a simple JSON schema
#'
#' The schema is a JSON file with fields:
#' - required: character[] of required column names
#' - types: named list mapping column names to expected types among
#'   c("character","double","integer","logical","date","datetime")
#' - allowed: named list mapping column names to allowed values (character[])
#'
#' @param df A data frame (tibble recommended).
#' @param schema_path Path to JSON schema file.
#' @return A list with elements:
#'   - issues: tibble of detected issues (row per issue)
#'   - summary: tibble summarizing counts per issue type
#'   - ok: logical whether zero issues were found
#' @examples
#' # df <- tibble::tibble(id = 1:3, title = c("a","b","c"))
#' # tmp <- tempfile(fileext = ".json")
#' # jsonlite::write_json(list(required = c("id","title"), types = list(id="integer", title="character")), tmp, auto_unbox = TRUE)
#' # out <- validate_schema(df, tmp)
#' # out$ok
#' @export
validate_schema <- function(df, schema_path) {
  stopifnot(file.exists(schema_path))
  schema <- jsonlite::read_json(schema_path, simplifyVector = TRUE)
  issues <- tibble::tibble(type = character(), column = character(), detail = character())

  # Required columns
  req <- schema$required %||% character()
  missing_cols <- setdiff(req, names(df))
  if (length(missing_cols)) {
    issues <- dplyr::bind_rows(issues, tibble::tibble(
      type = "missing_column",
      column = missing_cols,
      detail = "Required column missing"
    ))
  }

  # Types
  expected_types <- schema$types %||% list()
  for (col in names(expected_types)) {
    if (!col %in% names(df)) next
    want <- expected_types[[col]]
    got <- class(df[[col]])[1]
    # normalize to simple classes
    got_simple <- dplyr::case_when(
      inherits(df[[col]], "Date") ~ "date",
      inherits(df[[col]], "POSIXct") ~ "datetime",
      is.logical(df[[col]]) ~ "logical",
      is.integer(df[[col]]) ~ "integer",
      is.numeric(df[[col]]) ~ "double",
      is.character(df[[col]]) ~ "character",
      TRUE ~ got
    )
    if (!identical(want, got_simple)) {
      issues <- dplyr::bind_rows(issues, tibble::tibble(
        type = "type_mismatch",
        column = col,
        detail = paste0("Expected ", want, " but got ", got_simple)
      ))
    }
  }

  # Allowed values
  allowed <- schema$allowed %||% list()
  for (col in names(allowed)) {
    if (!col %in% names(df)) next
    bad <- unique(setdiff(stats::na.omit(df[[col]]), allowed[[col]]))
    if (length(bad)) {
      issues <- dplyr::bind_rows(issues, tibble::tibble(
        type = "disallowed_value",
        column = col,
        detail = paste0("Disallowed: ", paste(bad, collapse = ", "))
      ))
    }
  }

  summary <- issues |>
    dplyr::count(type, name = "n") |>
    tidyr::complete(type = c("missing_column","type_mismatch","disallowed_value"), fill = list(n = 0))

  list(issues = issues, summary = summary, ok = nrow(issues) == 0L)
}

# Null-coalescing helper
`%||%` <- function(x, y) if (is.null(x)) y else x
