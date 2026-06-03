# HPC Execution Guide for Data Curators

This guide explains how to execute the standalone inspection scripts from the Research Data Curator's Toolbox on an HPC cluster. It is written for data curators who need to assess large or complex deposits in a non-interactive environment, while keeping the workflow understandable, reproducible, and operational for colleagues.

The procedure documented here was validated on the `Fir` cluster of the Digital Research Alliance of Canada. The same overall strategy can be reused on other SLURM-based clusters with minor adjustments to module names and storage paths.

## Why use the HPC workflow

The notebooks published in the Toolbox book are intended to explain the logic of each curation module and to support interactive review. In practice, curators often need to inspect larger collections stored on cluster filesystems, where:

- the dataset is already in `scratch` or project storage;
- the work must run non-interactively;
- software is managed through environment modules;
- results must be written to stable output directories for later retrieval.

For these reasons, the repository includes standalone R scripts and a small HPC execution bundle that make it possible to run the workshop modules without cloning the full repository onto the cluster.

## Where the scripts come from

The source inspection scripts are stored in the repository under:

- [Scripts](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts)

These are the authoritative standalone curation scripts, including:

- [Inspect_Extensions_Script.R](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts/Inspect_Extensions_Script.R)
- [Inspect_csv_Script.R](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts/Inspect_csv_Script.R)
- [Inspect_Images_Script.R](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts/Inspect_Images_Script.R)
- [Inspect_hdf5_Script.R](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts/Inspect_hdf5_Script.R)
- [Inspect_nc_Script.R](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts/Inspect_nc_Script.R)
- [Inspect_PDF_Script.R](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts/Inspect_PDF_Script.R)
- [Inspect_sqlite_Script.R](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts/Inspect_sqlite_Script.R)

To make cluster execution easier, the repository also includes a minimal wrapper bundle under:

- [workshop/HPC/fir](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir)

This bundle contains Bash wrappers and a build script that copies only the required R scripts into a small upload package.

## What the minimal HPC bundle contains

The validated `Fir` bundle includes:

- [activate_fir_r_env.sh](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir/activate_fir_r_env.sh): loads R and defines `R_LIBS_USER`
- [setup_fir_r_env.sh](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir/setup_fir_r_env.sh): installs the required R packages
- [run_workshop_module.sh](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir/run_workshop_module.sh): runs one module directly
- [submit_workshop_module.sh](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir/submit_workshop_module.sh): submits one module through SLURM
- [build_fir_bundle.ps1](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir/build_fir_bundle.ps1): prepares the upload bundle from a local checkout

The design principle is simple: the curator uploads only the execution wrappers and the necessary inspection scripts, while leaving the dataset in HPC storage.

## Modules currently supported by the wrapper

The current wrapper accepts these module keys:

- `extensions`
- `csv`
- `images`
- `hdf5`
- `nc`
- `pdf`
- `sqlite`

If a workshop exercise only uses six modules, simply omit the one not required for that exercise.

## Recommended storage layout on the cluster

For clarity and reproducibility, the following layout is recommended in `scratch`:

- dataset directories remain where they already exist in `~/scratch` or project space
- the uploaded wrapper bundle lives in `~/scratch/bundle`
- outputs are written to `~/scratch/results`

This separation helps curators distinguish clearly between:

- source data under review
- executable code
- generated curation reports

## Step 1. Build the minimal bundle locally

On the local workstation, from the repository root, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\workshop\HPC\fir\build_fir_bundle.ps1
```

This creates:

```text
workshop/HPC/fir/bundle/
```

That generated directory contains:

- the Bash wrappers
- the required `Inspect_*.R` files in `r-scripts/`

## Step 2. Upload the bundle to the cluster

Copy the generated bundle to the cluster:

```powershell
scp -r .\workshop\HPC\fir\bundle <username>@fir.alliancecan.ca:~/scratch/
```

After logging in, verify the upload:

```bash
cd ~/scratch/bundle
find . -maxdepth 2 -type f | sort
find ~/scratch/bundle/r-scripts -maxdepth 1 -type f | sort
```

The second command should list the copied standalone inspection scripts.

## Step 3. Make the wrapper scripts executable

If the bundle was uploaded from Windows, the shell scripts may not yet be executable. Fix permissions once:

```bash
cd ~/scratch/bundle
chmod +x *.sh
```

## Step 4. Activate the R environment

From the bundle directory, activate the wrapper environment:

```bash
cd ~/scratch/bundle
source ./activate_fir_r_env.sh
```

This script:

- loads an available R module
- creates or reuses a user library at `R_LIBS_USER`
- prepares the shell for `R` and `Rscript`

It is good practice to confirm the executables:

```bash
which R
which Rscript
R --version
```

On `Fir`, this process was validated with `r/4.4.0`.

## Step 5. Install the required R packages

Once the environment is activated, install the package stack:

```bash
bash setup_fir_r_env.sh
```

The setup script installs the packages needed by the currently supported modules, including:

- `tidyverse`
- `readr`
- `skimr`
- `magick`
- `exiftoolr`
- `digest`
- `hdf5r`
- `tidync`
- `ncmeta`
- `pdftools`
- `DBI`
- `RSQLite`

### Important technical note

The setup script now uses `source` internally when loading the activation script. This is essential because the loaded R module must remain available in the current shell before `Rscript` is called.

## Step 6. Load scientific system modules when needed

Scientific file-format modules require system libraries as well as R packages. On `Fir`, the following modules were necessary:

```bash
module load netcdf/4.9.3 hdf5/1.14.6
```

These modules enabled successful installation of:

- `ncdf4`
- `RNetCDF`
- `hdf5r`
- `ncmeta`
- `tidync`

If these packages fail to install on another cluster, inspect the available modules with:

```bash
module spider netcdf
module spider hdf5
module avail netcdf
module avail hdf5
```

Then load the appropriate serial modules provided by the site.

## Step 7. Install ExifTool for metadata-rich file inventories

Two curation modules depend on ExifTool:

- `extensions`
- `images`

These modules use the R package `exiftoolr`, but `exiftoolr` alone is not sufficient. The underlying `exiftool` executable must also be available.

On `Fir`, the most reliable solution was a user-level installation from within R:

```bash
cd ~/scratch/bundle
source ./activate_fir_r_env.sh
Rscript -e "exiftoolr::install_exiftool()"
```

This installs ExifTool into the user space managed by `exiftoolr`. In the validated test, it was installed under:

```text
/home/<username>/.local/share/R/exiftoolr
```

Then verify the installation:

```bash
Rscript -e "cat(exiftoolr::exif_version(), '\n')"
```

On `Fir`, the validation returned ExifTool version `13.59`.

### Interpreting the verification output

During version detection, `exiftoolr` may first attempt to locate `exiftool` in the shell `PATH`. It can still print:

```text
sh: line 1: exiftool: command not found
```

and then continue successfully by using the local installation it manages itself.

If the command ultimately prints a version number such as `13.59`, ExifTool is working and the installation can be considered successful.

## Step 8. Run a module directly for a smoke test

Before launching scheduler jobs, it is helpful to validate one module interactively on a small, well-defined subset of the deposit.

The general form is:

```bash
bash run_workshop_module.sh <module> <input_dir> <output_root> [scripts_dir]
```

Example for CSV curation checks:

```bash
source ./activate_fir_r_env.sh
module load netcdf/4.9.3 hdf5/1.14.6
bash ./run_workshop_module.sh csv ~/scratch/HOBOLoggers ~/scratch/results ~/scratch/bundle/r-scripts
```

This should create results in:

```text
~/scratch/results/Inspect_csv
```

Verify the output:

```bash
find ~/scratch/results/Inspect_csv -maxdepth 1 -type f | sort
```

In the validated run on `Fir`, the CSV module produced:

- `CSV_Health_Check<date>.csv`
- `CSV_Full_Profile<date>.csv`

## Step 9. Run the PDF module

For PDF archival suitability checks:

```bash
source ./activate_fir_r_env.sh
module load netcdf/4.9.3 hdf5/1.14.6
bash ./run_workshop_module.sh pdf ~/scratch ~/scratch/results ~/scratch/bundle/r-scripts
```

Outputs are written to:

```text
~/scratch/results/Inspect_pdf
```

## Step 10. Run the NetCDF and HDF5 modules

For NetCDF:

```bash
source ./activate_fir_r_env.sh
module load netcdf/4.9.3 hdf5/1.14.6
bash ./run_workshop_module.sh nc ~/scratch ~/scratch/results ~/scratch/bundle/r-scripts
```

For HDF5:

```bash
source ./activate_fir_r_env.sh
module load netcdf/4.9.3 hdf5/1.14.6
bash ./run_workshop_module.sh hdf5 ~/scratch ~/scratch/results ~/scratch/bundle/r-scripts
```

Outputs are written respectively to:

- `~/scratch/results/Inspect_nc`
- `~/scratch/results/Inspect_hdf5`

## Step 11. Run the extensions and images modules after ExifTool is installed

Once ExifTool has been installed successfully, the metadata-intensive modules can be run.

For file extensions and inventory:

```bash
source ./activate_fir_r_env.sh
module load netcdf/4.9.3 hdf5/1.14.6
bash ./run_workshop_module.sh extensions ~/scratch/HOBOLoggers ~/scratch/results ~/scratch/bundle/r-scripts
```

For images:

```bash
source ./activate_fir_r_env.sh
module load netcdf/4.9.3 hdf5/1.14.6
bash ./run_workshop_module.sh images ~/scratch/Figures ~/scratch/results ~/scratch/bundle/r-scripts
```

### Important curatorial practice

Do not begin by pointing the `extensions` module at all of `~/scratch` unless that is truly the intended appraisal target.

In the validated test, running `extensions` against the entire `scratch` tree generated many expected ExifTool messages such as:

- `Unknown file type`
- `Entire file is binary zeros`
- `File format error`

These messages did not necessarily indicate failure. They reflected the heterogeneity of a large mixed deposit. For curation work, the better practice is to start with a specific deposit or series, such as:

- `~/scratch/HOBOLoggers`
- `~/scratch/Figures`
- a single project directory

This produces cleaner, faster, and easier-to-interpret reports.

## Step 12. Submit a module through SLURM

For production runs, use the scheduler wrapper rather than the login node.

General form:

```bash
bash submit_workshop_module.sh <module> <input_dir> <output_root> [scripts_dir] [time] [mem] [cpus]
```

Example:

```bash
bash submit_workshop_module.sh csv ~/scratch/HOBOLoggers ~/scratch/results ~/scratch/bundle/r-scripts 00:30:00 4G 1
```

The wrapper writes logs to:

```text
~/scratch/results/logs
```

Useful follow-up commands:

```bash
squeue -u $USER
find ~/scratch/results/logs -maxdepth 1 -type f | sort
tail -n 50 ~/scratch/results/logs/<job-log>.out
```

## Step 13. How the wrapper handles output directories

The standalone R scripts in this repository were written at different times and do not all handle `output_dir` in the same way. The wrapper normalizes this behavior for curatorial use on HPC systems.

It currently supports three patterns:

- `pass-output`: the wrapper passes the requested output directory directly to scripts that support it
- `sqlite-output`: the SQLite script expects the output root and appends `Inspect_sqlite` itself
- `fixed-output`: some scripts write to hard-coded internal paths such as `Results/Inspect_nc` or `Results/Inspect_pdf`; the wrapper runs them in an isolated working directory and then copies the generated reports into the requested results location

This is why curators should use the wrapper rather than calling the raw R scripts directly on the cluster.

## Step 14. Recommended execution order for training and appraisal

For workshops and operational testing, the following order is recommended:

1. `csv`
2. `pdf`
3. `hdf5`
4. `nc`
5. `sqlite`
6. `extensions`
7. `images`

This sequence starts with simpler dependencies, validates the environment progressively, and postpones ExifTool-dependent modules until ExifTool is confirmed to work.

## Step 15. Copy the reports back to the local workstation

Once the runs are complete, copy the results back with `scp`.

To retrieve all results:

```powershell
scp -r <username>@fir.alliancecan.ca:~/scratch/results d:\Alliance\RDM\
```

To retrieve only one module, for example the CSV reports:

```powershell
scp -r <username>@fir.alliancecan.ca:~/scratch/results/Inspect_csv d:\Alliance\RDM\
```

To retrieve the scheduler logs as well:

```powershell
scp -r <username>@fir.alliancecan.ca:~/scratch/results/logs d:\Alliance\RDM\
```

Before copying, it is useful to inspect the results tree on the cluster:

```bash
find ~/scratch/results -maxdepth 2 -type f | sort
```

## Step 16. Troubleshooting reference

### `Permission denied` when launching a shell script

Cause: uploaded `.sh` files do not have execute permissions.

Fix:

```bash
chmod +x *.sh
```

### `Rscript: command not found`

Cause: the R module is not loaded in the current shell.

Fix:

```bash
source ./activate_fir_r_env.sh
which Rscript
```

### `ncdf4`, `RNetCDF`, `hdf5r`, `ncmeta`, or `tidync` fail to install

Cause: NetCDF and HDF5 system libraries are not loaded.

Fix:

```bash
module load netcdf/4.9.3 hdf5/1.14.6
```

Then reinstall the failed R packages.

### `No functioning version of ExifTool has been found`

Cause: `exiftoolr` is installed, but the ExifTool executable has not yet been installed or detected.

Fix:

```bash
Rscript -e "exiftoolr::install_exiftool()"
Rscript -e "cat(exiftoolr::exif_version(), '\n')"
```

If the second command prints a version number, ExifTool is usable.

### Large numbers of `Unknown file type` or related ExifTool messages

Cause: the input directory contains many heterogeneous binary, scientific, or auxiliary files.

Interpretation:

- this does not necessarily indicate that the module failed;
- it usually means the appraisal target is too broad for an initial test.

Fix:

Run the module against a smaller deposit subset first, for example:

```bash
bash ./run_workshop_module.sh extensions ~/scratch/HOBOLoggers ~/scratch/results ~/scratch/bundle/r-scripts
```

### The wrapper is scanning the wrong collection

Cause: the input directory is the parent of the intended deposit.

Fix:

Pass the specific directory to be assessed rather than the whole storage area.

## Step 17. Good HPC practice for curators

- Use the login node only for setup, smoke tests, and short validation runs.
- Use `submit_workshop_module.sh` for production-scale inspection.
- Keep code, source data, and generated reports separated.
- Retain the generated CSV reports as formal curation evidence.
- Record which modules, paths, and cluster modules were used in case the appraisal needs to be repeated later.

## Step 18. Suggested future improvements

The current workflow is operational, but the repository would benefit from:

- publishing this guide in the Quarto book;
- standardizing all standalone scripts to accept `input_dir` and `output_dir` consistently;
- documenting site-specific ExifTool alternatives if a cluster provides a native module;
- adding cluster profiles beyond `Fir` if the toolbox is adopted more broadly.
