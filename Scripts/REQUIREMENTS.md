# Running the workshop scripts

Install everything once:

```bash
Rscript Scripts/install_requirements.R
```

It installs the R packages below and checks ExifTool. Needs R 4.1 or newer.

| Script | R packages | External tools |
|---|---|---|
| `Inspect_csv_Script.R` | tidyverse, skimr | none |
| `Inspect_nc_Script.R` | tidyverse, tidync, ncmeta | none |
| `Inspect_Extensions_Script.R` | tidyverse, exiftoolr | ExifTool (Perl on Windows) |
| `Inspect_Images_Script.R` | tidyverse, exiftoolr, magick, digest | ExifTool |
| `Inspect_PDF_Script.R` | tidyverse, pdftools | none |
| `Inspect_hdf5_Script.R` | tidyverse, hdf5r | none |
| `Inspect_sqlite_Script.R` | tidyverse, DBI, RSQLite | none |
| `Inspect_TidyData_Script.R` | tidyverse, readxl | none |
| `Inspect_ReadmeFileList_Script.R` | tidyverse | none |

## How to run

- **RStudio:** open the script and click *Source*. A window asks for the data folder (needs `rstudioapi`).
- **Terminal:** `Rscript Scripts/Inspect_csv_Script.R data/Inspect_csv/ Results/`
- Sample data for each script is in `data/Inspect_<type>/`.

Results are written to the output folder with the inspected folder's name in the file name.
