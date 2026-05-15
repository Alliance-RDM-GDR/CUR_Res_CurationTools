# Research Data Curator’s Toolbox

**Expert Workflows for Digital Curation & Preservation**

[![Quarto Publish](https://github.com/Alliance-RDM-GDR/CUR_Res_CurationTools/actions/workflows/publish.yml/badge.badge.svg)](https://github.com/Alliance-RDM-GDR/CUR_Res_CurationTools/actions/workflows/publish.yml)

This repository contains a professional collection of R-based workflows designed to support Research Data Management (RDM) tasks. It provides data curators with standardized, documented functions to transform raw data submissions into FAIR (Findable, Accessible, Interoperable, Reusable) research objects.

## 🌐 Live Website
The full documentation and interactive guide are available at:
👉 **[https://alliance-rdm-gdr.github.io/CUR_Res_CurationTools/](https://alliance-rdm-gdr.github.io/CUR_Res_CurationTools/)**

## 🛠 Key Features
- **Automated Triage**: Rapid inspection of file extensions and basic fixity.
- **Deep Validation**: Format-specific modules for Tabular (CSV, Excel, SPSS, SAS, Stata), Scientific (HDF5, NetCDF), and Geospatial (GeoPackage, TIFF) data.
- **OCR Intelligence**: Document extraction using Google Cloud AI.
- **Archival Reporting**: Generation of standardized curation logs and metadata summaries.

## 🚀 Quick Start

### Prerequisites
- [Quarto](https://quarto.org/docs/get-started/)
- [R](https://www.r-project.org/) and the libraries listed in the `Preface` or `load-libraries` chunks.

### Local Rendering
To preview the book locally:
```bash
quarto preview
```
To build the final version:
```bash
quarto render
```

## 📂 Project Structure
- `index.qmd`: Landing page with branding identity.
- `Inspect_*.qmd`: Format-specific curation notebooks.
- `Scripts/`: Standalone R scripts for batch processing.
- `data/`: Sample data for testing inspection routines.
- `styles/styles.css`: Alliance-branded visual theme.
- `references.bib`: Consolidated bibliography.

## 🤝 Contributing
Please see [CONTRIBUTING.md](CONTRIBUTING.md) for documentation standards and branding guidelines.

## 📜 License
This project is maintained by the Curation Services Team of the **Digital Research Alliance of Canada**.
