## Fir HPC Bundle

This directory contains the source files for the minimal `Fir` workshop bundle. It is intended for data curators who need to run the workshop inspection modules on the cluster while keeping the upload small and operationally simple.

## Included files

- `activate_fir_r_env.sh`: loads an available R module and prepares `R_LIBS_USER`
- `setup_fir_r_env.sh`: installs the R package stack needed by the supported workshop modules
- `run_workshop_module.sh`: runs a selected module directly
- `submit_workshop_module.sh`: submits a selected module through SLURM
- `build_fir_bundle.ps1`: creates the uploadable `bundle/` directory from this repository

## Supported module keys

- `extensions`
- `csv`
- `images`
- `hdf5`
- `nc`
- `pdf`
- `sqlite`

## Where the R scripts come from

The workshop bundle copies the required standalone inspection scripts from:

- [Scripts](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts)

The generated `bundle/r-scripts/` directory is therefore a deployment copy, not the primary source of truth.

## How the bundle should be used

1. Build the bundle locally with `build_fir_bundle.ps1`.
2. Upload the generated `bundle/` directory to `~/scratch` on `Fir`.
3. Activate the environment with `activate_fir_r_env.sh`.
4. Install dependencies with `setup_fir_r_env.sh`.
5. Run or submit workshop modules with the provided wrappers.

## Important notes for curators

- The bundle is designed so that the dataset can remain in cluster storage.
- The wrappers standardize output handling because not all standalone R scripts accept `output_dir` in the same way.
- The `extensions` and `images` modules require ExifTool in addition to the R package `exiftoolr`.
- The generated `bundle/` directory should not be committed to the repository.
