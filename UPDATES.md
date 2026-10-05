# Repository Updates

This file documents the evolution of the **Research Data Curator's Toolbox** from its inception to the current state.

## [2026-10-05] - Workshop Deck Update
- **New Modules**: Added Tidy Data screening (`Inspect_TidyData`) and README-vs-files comparison (`Inspect_ReadmeFileList`) to the workshop demos.
- **Designing for Scale**: New slide on header-only inspection, listing without unpacking, honest sampling and never executing inspected content, with the PPMstar simulation dataset as a worked example.
- **Concise Slides**: Shortened text-heavy slides; the deck now has 40 slides.
- **Speaker Notes**: Added English speaker notes to every slide (press **S** in the browser for presenter view).
- **Fixes**: Corrected result-file patterns used by the live demos and removed an empty slide.

## [2026-05-15] - UI/UX Professionalization & Branding
- **Branding Integration**: Applied official Alliance branding (Dark Teal, Tomorrow Yellow, Ubuntu/Montserrat typography).
- **Standardized Documentation**: Implemented "Curation Goal" and "Preservation Risk" callout blocks across all 21 notebooks.
- **Landing Page Redesign**: Complete overhaul of `index.qmd` with a modern hero banner and navigation grid.
- **Technical Cleanup**: Resolved duplicated chunk label warnings and consolidated the bibliography system (`references.bib`).
- **SQLite Support**: Finalized the inspection notebook for SQLite databases.

## [2026-04-10] - Repository Recovery
- Restored accidentally deleted files from the main branch.
- Consolidated development work into the Quarto book format.

## [2026-01-14] - Scientific Data Expansion
- Added support for genomic data (FASTQ format).

## [2026-01-05] - Image & Container Inspection
- Added specialized inspection for TIFF images and Container formats (Zip).

## [2025-12-22] - Structural Refactoring
- Major cleanup of the directory structure.
- Initial implementation of the bibliography configuration and per-chapter references.

## [2025-12-04] - Tabular Data Deep-Dive
- Expanded coverage for tabular formats (SPSS, Stata, SAS).
- Improved automation scripts for metadata extraction.

## [2025-11-18] - Book Architecture
- Transitioned the repository into a Quarto Book architecture with defined parts and chapters.
- Included new file types and updated notebook templates.

## [2025-09-19] - NetCDF & Geospatial
- Added initial support for NetCDF and geospatial data inspection.

## [2025-08-08] - Project Launch
- Initial creation of the repository and core README documentation.
- First scripts for CSV and image inspection (`Check_CSVs.R`, `Check_images.R`).

## [2024-11-04] - Project Inception
- Repository initialized.
- Setup of initial file naming conventions.
