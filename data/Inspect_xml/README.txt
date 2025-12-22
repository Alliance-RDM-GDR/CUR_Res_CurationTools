--------------------
GENERAL INFORMATION
--------------------

1. Title of Dataset: A high-resolution nested model to study the effects of alkalinity additions in Halifax Harbour: dataset of simulations

2. Author Information
	A. Principal Investigator Contact Information
		Name: Katja Fennel
		Institution:  Department of Oceanography, Dalhousie University, Halifax, Nova Scotia, Canada
		Email: Katja.fennel@dal.ca

	B. Co-investigator Contact Information
		Name: Arnaud Laurent
		Institution:  Department of Oceanography, Dalhousie University, Halifax, Nova Scotia, Canada
		Email: Arnaud.laurent@dal.ca

	C. Co-investigator Contact Information
		Name: Bin Wang
		Institution:  Department of Oceanography, Dalhousie University, Halifax, Nova Scotia, Canada
		Email: bin.wang@dal.ca

3. Date of data collection: simulation time range 2016-01-01 to 2023-12-31

4. Geographic location: Halifax, Nova Scotia, Canada

-----------------------
REPOSITORY DESCRIPTION
-----------------------

The dataset includes model simulations (incl. output and model grids) used in Laurent et al., 2025 (https://doi.org/10.5194/egusphere-2025-3361). The model is an implementation of the Regional Ocean Modelling System (ROMS) in a nested grid configuration with increasing spatial resolution from the Scotian Shelf to Halifax Harbour (coastal fjord, eastern Canada), a current test site for operational alkalinity addition. The biogeochemical model simulates oxygen dynamics, carbonate system processes (including air-sea gas exchange), and feedstock properties (dissolution, sinking). The first part of the dataset includes simulated time series at Station 2 (Scotian Shelf, 44.267°N/63.317°W) and at the compass buoy in the Bedford Basin (Halifax Harbour, 44.694°N/63.640°W) from multi-year hindcasts (2016-2023) with the coarsest (H1) and intermediate (H2) nested domains, respectively. Spatially resolved sea surface temperature in H1 is also included. The second part of the dataset provides model output for alkalinity addition experiments with 2 types of feedstock released at 3 locations inside and outside the Halifax Harbour. The experimental simulations are detailed in Laurent et al. (2025).

---------------------------
SHARING/ACCESS INFORMATION
---------------------------

1. Licenses/restrictions placed on the data:

These data are available under a CC BY 4.0 license <https://creativecommons.org/licenses/by/4.0/>

2. Recommended citation for this dataset:

Laurent, A., Wang, B., Fennel, K. (2025). A high-resolution nested model to study the effects of alkalinity additions in Halifax Harbour: dataset of simulations. Federated Research Data Repository. doi:10.20383/103.01525

---------------------
DATA & FILE OVERVIEW
---------------------

1. File List

   A. Filenames: - LaurentEtAl2025_BG_grid_H1.nc
	               - LaurentEtAl2025_BG_grid_H2.nc
	               - LaurentEtAl2025_BG_grid_H3.nc
       Short description: grid files for the nested grids H1 (coarse), H2 (intermediate) and H3 (high resolution)
   B. Filename: LaurentEtAl2025_BG_H1_sst.nc
       Short description: sea surface temperature for the long simulation with H1 (2016-2023)
	 C. Filename: LaurentEtAl2025_BG_H1_ST2.nc
       Short description: model output at Station 2 for the long simulation with H1 (2016-2023)
   D. Filename:  - LaurentEtAl2025_BG_H2_BBMP.nc
	               - LaurentEtAl2025_BG_H3_BBMP.nc
       Short description: model outputs at at the compass buoy station (BBMP, Bedford Basin) for the long simulation with H2 and H3 (2016-2023)
   E. Filenames: - LaurentEtAl2025_BG_H2_addTA_MillCove_dissolved_airsea.nc
	               - LaurentEtAl2025_BG_H2_addTA_MillCove_dissolved_tracers.nc
       Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H2 and dosing at Mill Cove (dissolved feedstock)
   F. Filenames: - LaurentEtAl2025_BG_H2_addTA_MillCove_particulate_airsea.nc
	               - LaurentEtAl2025_BG_H2_addTA_MillCove_particulate_tracers.nc
       Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H2 and dosing at Mill Cove (particulate feedstock)
   G. Filenames: - LaurentEtAl2025_BG_H2_addTA_TuftsCove_dissolved_airsea.nc
                 - LaurentEtAl2025_BG_H2_addTA_TuftsCove_dissolved_tracers.nc
       Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H2 and dosing at Tufts Cove (dissolved feedstock)
   H. Filenames: - LaurentEtAl2025_BG_H2_addTA_TuftsCove_particulate_airsea.nc
                 - LaurentEtAl2025_BG_H2_addTA_TuftsCove_particulate_tracers.nc
       Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H2 and dosing at Tufts Cove (particulate feedstock)
   G. Filenames: - LaurentEtAl2025_BG_H2_addTA_HerringCove_dissolved_airsea.nc
                 - LaurentEtAl2025_BG_H2_addTA_HerringCove_dissolved_tracers.nc
       Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H2 and dosing at Herring Cove (dissolved feedstock)
   H. Filenames: - LaurentEtAl2025_BG_H2_addTA_HerringCove_particulate_airsea.nc
                 - LaurentEtAl2025_BG_H2_addTA_HerringCove_particulate_tracers.nc
       Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H2 and dosing at Herring Cove (particulate feedstock)
   E. Filenames: - LaurentEtAl2025_BG_H3_addTA_MillCove_dissolved_airsea.nc
                 - LaurentEtAl2025_BG_H3_addTA_MillCove_dissolved_tracers.nc
		Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H3 and dosing at Mill Cove (dissolved feedstock)
   F. Filenames: - LaurentEtAl2025_BG_H3_addTA_MillCove_particulate_airsea.nc
                 - LaurentEtAl2025_BG_H3_addTA_MillCove_particulate_tracers.nc
		Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H3 and dosing at Mill Cove (particulate feedstock)
   G. Filenames: - LaurentEtAl2025_BG_H3_addTA_TuftsCove_dissolved_airsea.nc
                 - LaurentEtAl2025_BG_H3_addTA_TuftsCove_dissolved_tracers.nc
		Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H3 and dosing at Tufts Cove (dissolved feedstock)
   H. Filenames: - LaurentEtAl2025_BG_H3_addTA_TuftsCove_particulate_airsea.nc
                 - LaurentEtAl2025_BG_H3_addTA_TuftsCove_particulate_tracers.nc
		Short description: spatially resolved model tracers and CO2 air-sea fluxes time series for the simulation with H3 and dosing at Tufts Cove (particulate feedstock)

---------------------------
METHODOLOGICAL INFORMATION
---------------------------

1. Description of methods used for collection/generation of data:

The circulation model is a regional implementation of the Regional Ocean Modelling System (ROMS 3.9; https://github.com/myroms/roms) configured for the Halifax Harbour and surrounding areas with 3 nested domains of increasing resolution towards the harbour. The grids have 40 vertical layers and an horizontal resolution of 760m (H1), 150m (H2) and 50m (H3). The circulation model uses the 3rd-order upstream-biased (horizontal) and 4th-order centered differences (vertical) advection schemes for temperature and salinity. The model includes 17 freshwater inputs and is forced by the ERA5 atmospheric product (https://doi.org/10.1002/qj.3803) at the surface and by output from a larger model at the boundaries. The models include tides. The larger model is forced by GLORYS (https://doi.org/10.3389/feart.2021.698876).
The circulation model is coupled online with a biogeochemical model that simulates the effect of alkalinity addition on the carbonate system. The model has 5 state variables: Alkalinity (TA), TIC, ∆TA, ∆TIC and particles (alkalinity equivalent).

-------------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: LaurentEtAl2025_BG_H1_ST2.nc
-------------------------------------------------------------------

Variable List:

    1. Name: mask_rho
       Description: land (0) sea (1) mask for the model grid. Each vertical layer has the same mask

    2. Name: h
       Description: Bathymetry of the model grid cells

    3. Name: lon_rho
       Description: Longitude of the model grid cells on the rho-grid (tracers).

    4. Name: lat_rho
       Description: Latitude of the model grid cells on the rho-grid (tracers).

    5. Name: z_rho
       Description: Time varying (including zeta) mid depth of each vertical layers on the rho-grid (tracers).

    6. Name: z_w
       Description: Time varying (including zeta) top and bottom depth of each vertical layers on the rho-grid (tracers).

    7. Name: NO3
       Description: Nitrate concentration

    8. Name: NH4
       Description: Ammonium concentration

    9. Name: PO4
       Description: Phosphate concentration

    10. Name: small_phyto
       Description: Nanophytoplankton

    11. Name: large_phyto
       Description: Large phytoplankton

    12. phyS_chl small
       Description: Chlorophyll concentration for nanophytoplankton

    13. Name: phyL_chl
       Description: Chlorophyll concentration for large phytoplankton

    14. Name: small_zoo
       Description: Microzooplankton

    15. Name: large_zoo
       Description: Mesozooplankton

    16. Name: LdetritusN
       Description: Large fraction nitrogen detritus concentration

    17. Name: SdetritusN
       Description: Small fraction nitrogen detritus concentration

    18. Name: LdetritusC
       Description: Large fraction carbon detritus concentration

    19. Name: SdetritusC
       Description: Small fraction carbon detritus concentration

    19. Name: oxygen
       Description: Dissolved oxygen concentration

    20. Name: temp
       Description: Potential temperature

    21. Name: salt
       Description: Salinity

    22. Name: ocean_time
       Description: Time of the simulation in seconds since 1980-01-01

-------------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: LaurentEtAl2025_BG_H1_sst.nc
-------------------------------------------------------------------

Variable List:

   1. Name: lon_rho
      Description: Longitude of the model grid cells on the rho-grid (tracers).

   2. Name: lat_rho
      Description: Latitude of the model grid cells on the rho-grid (tracers).

   3. Name: z_rho
      Description: Time varying (including zeta) mid depth of each vertical layers on the rho-grid (tracers).

   4. Name: temp
      Description: Potential temperature

   5. Name: ocean_time
      Description: Time of the simulation in seconds since 1980-01-01

-------------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: LaurentEtAl2025_BG_H?_BBMP.nc
-------------------------------------------------------------------

Variable List:

    1. Name: mask_rho
       Description: land (0) sea (1) mask for the model grid. Each vertical layer has the same mask

    2. Name: h
       Description: Bathymetry of the model grid cells

    3. Name: lon_rho
       Description: Longitude of the model grid cells on the rho-grid (tracers).

    4. Name: lat_rho
       Description: Latitude of the model grid cells on the rho-grid (tracers).

    5. Name: z_rho
       Description: Time varying (including zeta) mid depth of each vertical layers on the rho-grid (tracers).

    6. Name: z_w
       Description: Time varying (including zeta) top and bottom depth of each vertical layers on the rho-grid (tracers).

    7. Name: alkalinity
       Description: Total alkalinity

    8. Name: TIC
       Description: Total inorganic carbon

    9. Name: oxygen
       Description: Dissolved oxygen concentration

    10. Name: temp
       Description: Potential temperature

    11. Name: salt
       Description: Salinity

    12. Name: ocean_time
       Description: Time of the simulation in seconds since 1980-01-01

-------------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: LaurentEtAl2025_BG_*_tracers.nc
-------------------------------------------------------------------

Variable List:

    1. Name: mask_rho
       Description: land (0) sea (1) mask for the model grid. Each vertical layer has the same mask

    2. Name: lon_rho
       Description: Longitude of the model grid cells on the rho-grid (tracers). The equivalent variable is available on the u-grid and v-grid for u and v, respectively.

    3. Name: lat_rho
       Description: Latitude of the model grid cells on the rho-grid (tracers). The equivalent variable is available on the u-grid and v-grid for u and v, respectively.

    4. Name: z_rho
       Description: Time varying (including zeta) mid depth of each vertical layers on the rho-grid (tracers). The equivalent variable is available on the u-grid and v-grid for u and v, respectively.

    5. Name: z_w
       Description: Time varying (including zeta) top and bottom depth of each vertical layers on the rho-grid (tracers). The equivalent variable is available on the u-grid and v-grid for u and v, respectively.

    6. Name: particle1
       Description: Total alkalinity feedstock in the particulate phase

    7. Name: alkalinity
       Description: Total alkalinity (control or counterfactual, unaffected by alkalinity addition)

    8. Name: dTA
       Description: Change in total alkalinity (∆TA) resulting from the alkalinity addition (i.e., total alkalinity feedstock in the dissolved phase)

    9. Name: TIC
       Description: Total inorganic carbon (control or counterfactual, unaffected by alkalinity addition)

   10. Name: dTIC
       Description: Change in total inorganic carbon (∆TIC) resulting from the alkalinity addition

   17. Name: ocean_time
       Description: Time of the simulation in seconds since 1980-01-01

 -------------------------------------------------------------------
 DATA-SPECIFIC INFORMATION FOR: LaurentEtAl2025_BG_*_airsea.nc
 -------------------------------------------------------------------

 Variable List:

		1. Name: CO2c_airsea
		   Description: Daily average of air-sea CO2 flux (control or counterfactual, unaffected by alkalinity addition)

		2. Name: CO2a_airsea
		   Description: Daily average of air-sea CO2 flux with alkalinity addition

    1. Name: O2_airsea
	 		   Description: Daily average of air-sea O2 flux

		3. Name: ocean_time
		   Description: Time (mid day) for the daily averaged output in seconds since 1980-01-01

		4. Name: lon_rho
		   Description: Longitude of the model grid cells (rho-grid)

		5. Name: lat_rho
		   Description: Latitude of the model grid cells (rho-grid)
