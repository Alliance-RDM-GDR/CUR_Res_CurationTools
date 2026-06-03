# HPC Workshop Materials

This directory contains the HPC execution materials for the workshop. It is intended for data curators who want to run the standalone curation scripts on a cluster without cloning the full repository into the compute environment.

## What is included

- [HPC_Execution_Guide.md](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/HPC_Execution_Guide.md): the full curator-facing guide for preparing, running, troubleshooting, and retrieving HPC results
- [fir](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir): the `Fir`-specific wrapper bundle source files

## Where the inspection scripts come from

The standalone inspection scripts used by the workshop are stored in:

- [Scripts](/d:/Alliance/RDM/CUR_Res_CurationTools/Scripts)

The `Fir` bundle does not replace those scripts. It packages only the wrappers and the subset of `Inspect_*.R` files needed to run the workshop modules on the cluster.

## How a curator should use this directory

1. Read [HPC_Execution_Guide.md](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/HPC_Execution_Guide.md).
2. Build the minimal upload bundle with [build_fir_bundle.ps1](/d:/Alliance/RDM/CUR_Res_CurationTools/workshop/HPC/fir/build_fir_bundle.ps1).
3. Upload the generated `bundle/` directory to `Fir`.
4. Run the workshop modules on the target deposit using the Bash wrappers from the bundle.

## Important scope note

The generated `bundle/` directory is a deployment artifact. It should be created locally when needed and uploaded to the cluster, but it should not be committed back into the repository.
