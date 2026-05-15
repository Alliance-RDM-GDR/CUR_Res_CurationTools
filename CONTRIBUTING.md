# Contributing to the Research Data Curator's Toolbox

Thank you for your interest in contributing! This project aims to provide high-quality, standardized R workflows for data curation. To maintain professionalism and consistency, please follow these guidelines.

## 🛠 Technical Stack
- **Quarto**: The documentation is built using [Quarto Books](https://quarto.org/docs/books/).
- **R**: Curation logic must be written in R, following `tidyverse` principles where possible.
- **Organization**: Every format-specific inspection should consist of:
  1. A Quarto notebook (`Inspect_[format]_Notebook.qmd`).
  2. A standalone R script in the `Scripts/` directory for batch processing.

## 🎨 Documentation Standards

To ensure a "Preservation-First" pedagogical approach, every new notebook MUST include the following elements in the `## Overview` section:

### 1. Standard Callouts
Use the Quarto callout syntax to provide immediate context:

```markdown
::: {.callout-note title="Curation Goal"}
Briefly state what the curator aims to achieve (e.g., "Validate structural integrity and verify CRS").
:::

::: {.callout-warning title="Preservation Risk"}
Identify format-specific risks (e.g., "Missing metadata, proprietary compression, or brittle multi-file structures").
:::
```

### 2. Branding Colors
Follow the Alliance brand identity:
- **Headers**: Use the Ubuntu font and Dark Teal color (`#006666`).
- **Body**: Use Montserrat font.
- **Accents**: Use Tomorrow Yellow (`#D6AB00`) for emphasis.

## 📚 References & Bibliography
- All citations must be added to `references.bib` in BibTeX format.
- Use unique keys (e.g., `@pebesma2018`).
- Ensure every notebook has a `## References` section at the end:
  ```markdown
  ## References
  ::: {#refs}
  :::
  ```

## 🚀 Workflow
1. **Create a Branch**: Work on a descriptive branch (e.g., `feature/add-fastq-support`).
2. **Standardize**: Apply the callout blocks and branding styles.
3. **Validate**: Run `quarto render` locally to ensure no warnings (e.g., duplicated chunk labels).
4. **Commit**: Use clear, English-only commit messages.
5. **Pull Request**: Submit a PR to the `dev-book` branch for review.

---
*Questions? Contact the Curation Services Team.*
