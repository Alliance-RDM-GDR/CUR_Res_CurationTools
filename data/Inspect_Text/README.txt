This README.txt file was generated on 2025-11-24 by Afshin Shaygani

--------------------
GENERAL INFORMATION
--------------------

1. Title of Dataset:
HCX-IR High-Resolution (1/8°) Observational and CMIP6 Downscaled Climate Dataset for Iran

2. Author Information
    A. Principal Investigator Contact Information
        Name: M. Reza Najafi
        Institution: Western University, Department of Civil and Environmental Engineering
        Email: mnajafi7@uwo.ca
		ORCID: https://orcid.org/0000-0002-1652-3135 

    B. Dataset Authors 
        (These individuals directly contributed to dataset generation  
         including observational data processing and downscaling workflows).
		- Mohammad Sadegh Abbasian https://orcid.org/0000-0002-2041-2083
		- Farshad Jalili Pirani   https://orcid.org/0000-0002-7609-8185
		- Melika RahimiMovaghar
		- Reza Rezvani	

	C. Acknowledgments (non-author contributors)  
		- Dr. Afshin Shaygani https://orcid.org/0000-0002-2371-9953
		  (FRDR dataset preparation, file organization, deposition)  
		- HydroClimEX Lab members supporting preprocessing and technical tasks 		

3. Date of data collection (single date, range, approximate date):
Observational data: 1980-01-01 to 2012-12-31
CMIP6 historical + future simulations: 1980-01-01 to 2100-12-31

4. Geographic location of data collection:
Iran, Southwest Asia
Approximate extent: 25°N–40°N, 44°E–64°E
Spatial resolution: 1/8° 

5. Information about funding sources that supported the collection of the data:
None.


---------------------------
SHARING/ACCESS INFORMATION
---------------------------

1. License:
CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

2. Links to publications using the data:
Najafi MR, Abbasian M, Na W, RahimiMovaghar M, Bakhtiari S, Islam MR, Fereshtehpour M, Jalili Pirani F, Rezvani R.
Multi-Model Projection of Climate Extremes under 1.5°C–4°C Global Warming Levels across Iran.  
International Journal of Climatology, 45(4): e8740 (2025).

3. Links/relationships to ancillary data sets:
None

5. Was data derived from another source? yes
    A. If yes, list source(s):
       CMIP6 GCMs: CanESM5, CNRM-CM6-1, GFDL-ESM4, MIROC-ES2L, MPI-ESM1-2-HR, MPI-ESM1-2-LR, NorESM2-LM, IPSL-CM6A-LR.
       Observational network: Iran Meteorological Organization synoptic stations.

6. Recommended citation for this dataset:
Najafi M.R., Abbasian M., Jalili Pirani F., RahimiMovaghar M., Rezvani R. (2025)., HCX-IR High-Resolution Observational and CMIP6 Downscaled Climate Dataset for Iran  
(HCX-IR-Obs, HCX-IR-MBC_CMIP6, HCX-IR-BCCAQ_CMIP6). Federated Research Data Repository (FRDR). DOI: to be assigned.


---------------------
DATA & FILE OVERVIEW
---------------------

1. File List (summary of standard naming conventions)

A. Observational Dataset  
   Filename: HCX-IR-Obs_daily_1980-2012.nc  
   Description: Gridded observational dataset including pr, tasmin, tasmax.

B. MBC Downscaled Output  
   Filename pattern: Biascorrected_<MODEL>_<SCENARIO>_pr_tasmax_tasmin.nc  
   Description: MBCn bias-corrected CMIP6 daily variables.

C. Raw GCM Extract  
   Filename pattern: <MODEL>_<SCENARIO>.nc  
   Description: CMIP6 raw daily outputs subset over Iran.

D. BCCAQ Downscaled Output  
   Filename pattern: <MODEL>_<SCENARIO>_<VARIABLE>_BCCAQ.nc  
   Description: Daily CMIP6 downscaled data using BCCAQ V2  
   Variables stored separately (pr, tasmin, tasmax).

2. Relationship between files:
	- All datasets share the same 1/8° grid and domain.  
	- Each CMIP6 model has two downscaling methods: MBC and BCCAQ.  
	- Observations and downscaled outputs use consistent units and CF-compliant metadata.

3. Additional related data not included:
None.

4. Multiple dataset versions?
No.

----------------------------------------------------
FOLDER STRUCTURE OVERVIEW
----------------------------------------------------

Top-level directories:

HCX-IR-Obs/  
    Contains observational dataset  
    → HCX-IR-Obs_daily_1980-2012.nc  

HCX-IR-MBC_CMIP6/  
    Organized by GCM, then scenario  
    Example:  
      CNRM_CM6_1/  
         ssp245/  
            Biascorrected_CNRM_CM6_1_ssp245_pr_tasmax_tasmin.nc  
            CNRM_CM6_1_ssp245.nc  
         ssp585/  
            Biascorrected_CNRM_CM6_1_ssp585_pr_tasmax_tasmin.nc  
            CNRM_CM6_1_ssp585.nc (raw GCM) 

HCX-IR-BCCAQ_CMIP6/  
    Variables stored separately  
    Example:  
      CNRM_CM6_1_ssp245/  
         CNRM_CM6_1_ssp245_pr_BCCAQ.nc  
         CNRM_CM6_1_ssp245_tasmin_BCCAQ.nc  
         CNRM_CM6_1_ssp245_tasmax_BCCAQ.nc  
		 
		 
---------------------------
METHODOLOGICAL INFORMATION
---------------------------

1. Data generation:

Observations:
	- Derived from Iran synoptic stations.  
	- Interpolated to 1/8° using SYMAP-based methods.  
	- Validated using CRU, NCEP, and 20CR datasets.

CMIP6 Downscaling:
	- MBCn method applied to pr, tasmin, tasmax.  
	- BCCAQ v2 applied using PCIC standard workflow.

2. Processing:
	- Daily data processed for historical and ssp245/ssp585 scenarios (1980–2100).  
	- Validation via climatology, extremes indices, and spatial diagnostics.

3. Tools and methods required for interpretation:
	- SYMAP interpolation  
	- MBCn algorithm  
	- BCCAQ V2  
	- Standard NetCDF tools  

4. Standards and calibration:
	- Observations quality-controlled and cross-validated with global datasets.

5. Environmental/experimental conditions:
	Not applicable.

6. Quality assurance:
	- Checked spatial continuity, annual cycles, and distributions of extremes (TXx, TNn, RX1day, etc.).

7. Personnel involved:
	- Data generation: Najafi, Abbasian, Jalili Pirani, RahimiMovaghar, Rezvani  
	- Dataset preparation/upload: Afshin Shaygani  
	- QC and domain review: HydroClimEX Lab


---------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: HCX-IR-MBC_CMIP6 (EXAMPLE)
---------------------------------------------------------------

1. Number of variables:
3 (pr, tasmin, tasmax)

2. Number of cases:
Daily values from 1980–2100

3. Missing data codes:
Standard NetCDF missing values (e.g., 1e20) may apply.

4. Variable List:

   A. pr  
      Daily precipitation (mm/day)

   B. tasmin  
      Minimum daily temperature (°C)

   C. tasmax  
      Maximum daily temperature (°C)
