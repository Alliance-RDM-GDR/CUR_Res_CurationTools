#' Check filename policy compliance
#'
#' Enforces a simple filename policy: lowercase ASCII, hyphen separators,
#' and allowed extensions.
#'
#' @param x A single filename (character scalar).
#' @param allowed_ext Character vector of allowed extensions (lowercase, no dot).
#'   Defaults to common archival/documentation types.
#' @return Logical: TRUE if compliant, FALSE otherwise.
#' @examples
#' frdr_filename_check("readme.md")
#' frdr_filename_check("data-dictionary.csv")
#' frdr_filename_check("Raw Data.xlsx")  # FALSE (space + uppercase + xlsx not listed by default)
#' @export
frdr_filename_check <- function(x,
  allowed_ext = c("csv","tsv","txt","md","json","yaml","yml","rdf","ttl","tif","tiff","png","jpg","jpeg","pdf","rds","rda")) {

  stopifnot(length(x) == 1L, is.character(x))
  # ASCII only
  ascii_ok <- all(charToRaw(x) < 128)
  # lowercase + no spaces
  lc_ok <- (x == tolower(x)) && !grepl("\s", x)
  # use hyphens or underscores (no consecutive punctuation)
  punct_ok <- !grepl("[^a-z0-9._-]", x) && !grepl("[._-]{2,}", x)
  # extension check
  ext <- tolower(gsub("^.*\.", "", x))
  has_ext <- grepl("\.", x)
  ext_ok <- has_ext && ext %in% allowed_ext

  isTRUE(ascii_ok && lc_ok && punct_ok && ext_ok)
}
