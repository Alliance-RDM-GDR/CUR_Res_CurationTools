# Render the entire book from R (optional)
if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("Please install Quarto CLI and the 'quarto' R package.")
}
quarto::quarto_render(input = ".")
