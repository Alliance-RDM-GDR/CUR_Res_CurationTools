This README file was written on 19 June 2024 by Dr. Ruping Mo, Meteorological
Service Canada, Environment and Climate Change Canada (ruping.mo@ec.gc.ca).

-------------------
GENERAL INFORMATION
-------------------

1. Title of Dataset:
    An ERA5-based Dataset for Atmospheric River Analysis (EDARA): Multi-decade
    numerical and graphical catalogues

2. Author Information
    Name: Ruping Mo
    Email: ruping.mo@ec.gc.ca
    Institution: Environment and Climate Change Canada

3. Date of data collection: 
    This is a 6-hourly dataset available from 0000 UTC 1 January 1940 onwards. 
SHARING/ACCESS INFORMATION
4. Geographic location of data collection:
    This is a global dataset available on a regular latitude-longitude grid of 
    0.25 degrees

--------------------------
SHARING/ACCESS INFORMATION
--------------------------

1. Licenses/restrictions placed on the data: 
    These data are available under a CC BY 4.0 license 
    [https://creativecommons.org/licenses/by/4.0/] 

2. Links to publications that cite or use the data:
    These data are described in the following article:
    Mo, R. (2024). EDARA: An ERA5-based Dataset for Atmospheric River Analysis. 
    Scientific Data, 11, 900, https://doi.org/10.1038/s41597-024-03679-1 

3. Were data derived from another source? yes
    These data were derived from the European Centre for Medium-Range Weather 
    Forecasts atmospheric reanalysis version 5 (ERA5), available through the 
    Copernicus Climate Change Serivce Climate Data Store: 
    1) Hersbach, H., Bell, B., Berrisford, P., Hirahara, S., Horányi, A., 
       Muñoz‐Sabater, J., Nicolas, J., Peubey, C., Radu, R., Schepers, D., 
       Simmons, A., Soci, C., Abdalla, S., Abellan, X., Balsamo, G., 
       Bechtold, P., Biavati, G., Bidlot, J., Bonavita, M., De Chiara, G., 
       Dahlgren, P., Dee, D., Diamantakis, M., Dragani, R., Flemming, J., 
       Forbes, R., Fuentes, M., Geer, A., Haimberger, L., Healy, S., 
       Hogan, R.J., Hólm, E., Janisková, M., Keeley, S., Laloyaux, P., 
       Lopez, P., Lupu, C., Radnoti, G., de Rosnay, P., Rozum, I., Vamborg, F.,
       Villaume, S., Thépaut, J-N. (2017): Complete ERA5 from 1940: Fifth 
       generation of ECMWF atmospheric reanalyses of the global climate. 
       Copernicus Climate Change Service (C3S) Data Store (CDS), 
       https://doi.org/10.24381/cds.143582cf (Accessed on 10-Apr-2024).
    2) Simmons, A., Soci, C., Nicolas, J., Bell, B., Berrisford, P., Dragani, R.,
       Flemming, J., Haimberger, L., Healy, S., Hersbach, H., Horányi, A., 
       Inness, A., Munoz-Sabater, J., Radu, R., Schepers, D. (2020): ERA5.1: 
       Rerun of the Fifth generation of ECMWF atmospheric reanalyses of the 
       global climate (2000-2006 only). Copernicus Climate Change Service (C3S) 
       Data Store (CDS), https://doi.org/10.24381/cds.143582cf (Accessed on 
       10-Apr-2024). 

4. Recommended citation for this dataset:
    Mo, R. (2024). An ERA5-based Dataset for Atmospheric River Analysis (EDARA):
    Multi-decade numerical and graphical catalogues. Federated Research Data 
    Repository. https://doi.org/10.20383/103.0935.

---------------------
DATA & FILE OVERVIEW
---------------------  

1. File list

This dataset (EDARA) contains three folders: data, figs, and misc. The data and 
figs folders contain the numerical and graphical data, respectively. The misc 
folder contains codes and example data.

  1) Numerical data under the "data" folder:
     6-hourly gridded data of 12 variables derived from ERA5 for each month are 
     included in a netCDF file named "era5dara_yyyymm.nc", where yyyy and mm 
     represent year and month, respectively (e.g., era5dara_202111.nc).

  2) Graphical catalogues under the "figs" folder:
     Under the "figs" folder, there are monthly subfolders named "yyyy_mm", 
     where yyyy and mm represent year and month, respectively (e.g., 2021_11).
     Each monthly subfolder contains an index.html file and two subfolders: gb
     and na. The index.html file can be opened using a web browser to display 
     graphical representation of atmospheric rivers over the global domain in 
     the "gb" subfolder and the North American domain in the "na" subfolder.

  3) File list under the "misc" folder: 

     (1) Derive_variables_from_ERA5.py:
         A demo python program showing how to derive variables included in this
         dataset (EDARA) from the original ERA5 data

     (2) ERA5_pl_20211114_0000utc.nc:
         A netCDF data file containing some ERA5 pressure-level variables valid
         at 0000 UTC 14 November 2021, downloaded from the C3S Climate Data
         Store (https://doi.org/10.24381/cds.143582cf)

     (3) ERA5_sl_20211114_0000utc.nc:
         A netCDF data file containing some ERA5 single-level variables valid 
         at 0000 UTC 14 November 2021, downloaded from the C3S Climate Data 
         Store (https://doi.org/10.24381/cds.143582cf)

     (4) ERA5_hrly_tp_20211113.nc:
         A netCDF data file containing hourly total precipitation on 13
         November 2021, downloaded from the C3S Climate Data Store
         (https://doi.org/10.24381/cds.143582cf)

     (5) ERA5_hrly_tp_20211114.nc:
         A netCDF data file containing hourly total precipitation on 14
         November 2021, downloaded from the C3S Climate Data Store
         (https://doi.org/10.24381/cds.143582cf)

     (6) Extract_variables_from_era5dara.py:
         A demo python program showing how to extract variables from a netCDF 
         data file under the "data" folder

     (7) mtarget.m:
         A MATLAB program for the tARget-v3 algorithm and a modified version of
         it (mtARget-v3) 

     (8) ERA5_ivt_tARget_202111.nc:
         A netCDF data file containing 6-hourly eastward and northward 
         components of integrated water vapour flux in November 2021 (needed as
         an input file for running mtarget.m)

     (9) ERA5_islnd.nc:
         A netCDF data file with a variable named 'islnd' conaining land-sea  
         mask (needed as an input file for running mtarget.m)

     (10) ERA5_monthly_pixel_ivt_limit.nc:
          A netCDF data file containing IVT percentile limits (needed as an
          input file for running mtarget.m)

     (11) out_202111.nc:
          The output file from running mtarget.m with key = 0 for the tARget-v3
          algorithm. It contains a variable named 'shape' for atmospheric river
          shape, which can be converted to the ARS variable in EDARA

     (12) mout_202111.nc:
          The output file from running mtarget.m with key = 1 for the mtARget-v3
          algorithm. It contains a variable named 'shape' for atmospheric river
          shape, which can be converted to the MARS variable in EDARA

 4) README.txt: This document

2. Relationship between files, if important: 

   1) The python program misc/Derive_variables_from_ERA5.py needs input data
      stored in the following six files:
      misc/ERA5_sl_20211114_0000utc.nc
      misc/ERA5_pl_20211114_0000utc.nc
      misc/ERA5_hrly_tp_20211113.nc
      misc/ERA5_hrly_tp_20211114.nc
      misc/out_202111.nc
      misc/mout_202111.nc
  
   2) The python program misc/Extract_variables_from_era5dara.py reads input
      data stored in the following file:
      data/era5dara_202111.nc. 

   3) The MATLAB program misc/mtarget.m reads input data stored in the 
      following three files:
      misc/ERA5_ivt_tARget_202111.nc
      misc/ERA5_islnd.nc
      misc/ERA5_monthly_pixel_ivt_limit.nc

   4) The MATLAB program misc/mtarget.m with key = 0 outputs the file:
      misc/out_202111.nc

   5) The MATLAB program misc/mtarget.m with key = 1 outputs the file:
      misc/mout_202111.nc

3. Are there multiple versions of the dataset? no

---------------------------
METHODOLOGICAL INFORMATION
---------------------------

1. Summary:
   EDARA is an ERA5-based sub-dataset intended to support various analyses related 
   to atmospheric rivers (ARs). ERA5 pressure-level specific humidity, temperature, 
   geopotential, eastward and northward wind components, together with single-level
   variables of pressure, precipitation, wind, and temperature, are downloaded to 
   produce this 6-hourly EDARA suite at 0000, 0600, 1200, and 1800 UTC. 
   1) Vertically integrated variables (Qu, Qv, IWV, CRH) are obtained from 
      integration from the Earth's surface up to the 200-hPa pressure level.
   2) Total Precipitation Rate (TPR) is the sum of the four precipitation 
      intensity parameters in ERA5: the rates of convective and large-scale rain
      and snowfall water equivalent.
   3) 10 metre Gusty Wind Speed (GWS10m) is defined as the larger value between 
      the analysed 10 metre wind speed (WS10m) and the diagnosed 10 metre wind 
      gusts (WG10m), i.e., GWS10m = max(WS10m, WG10m).
   4) Lower-Tropospheric Mean Temperature (LTMT) is based on the geopotential
      height thickness between the 500 and 1000 hPa pressure levels (ZT):
      LTMT(in K) = 0.0493 * ZT(in m).
   5) Mean Sea-Level Pressure (MSLP) and 2 metre Temperature (T2m) are directly
      extracted from ERA5. They are included in EDARA to facilitate analyses of
      pressure distribution and frontal features associated with the atmospheric
      river systems.
   6) Atmospheric River Shapes (ARS, MARS) are computed based on the tARget-v3
      algorithm of Guan and Waliser (2019) and the 30-year (1991-2020) climatology 
      of the Integrated Vapour Transport [IVT = sqrt(Qu*Qu + Qv*Qv)]. 

2. Detailed description of methods used for collection/generation of data:
     The methodology for data collection and generation is described in the
     following paper:
     Mo, R. (2024). EDARA: An ERA5-based Dataset for Atmospheric River Analysis.
     Scientific Data, 11, 900, https://doi.org/10.1038/s41597-024-03679-1

3. Computational codes for data collection/generation: 
     Data processing methods can be implemented using the algorithms presented
     in the python program misc/Derive_variables_from_ERA5.py and the MATLAB
     program misc/mtarget.m. Comments in these programs can also serve as
     specific instructions to process the data.

--------------------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: netCDF files in the data folder (data/*.nc)
--------------------------------------------------------------------------

1. Source: Derived or extracted from ERA5 available from the C3S Climate Data 
           Store (https://doi.org/10.24381/cds.143582cf) 

1. Number of variables (including dimensional variables): 15

2. Variable list:

    Variable: longitude
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: latitude
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: Qu
    Description: Eastward component of the integrated water vapour flux
    Integration limit: From surface to 200 hPa
    Units: kg m**-1 s**-1

    Variable: Qv
    Description: Northward component of the integrated water vapour flux
    Integration limit: From surface to 200 hPa
    Units: kg m**-1 s**-1

    Variable: IWV
    Description: Integrated water vapour
    Integration limit: From surface to 200 hPa
    Units: kg m**-2

    Variable: CRH
    Description: Column relative humidity, defined as CRH = IWV/ISWV, where
                 ISWV is the integrated saturation water vapour
    Units: none

    Variable: TPR
    Description: Total precipitation rate
    Units: kg m**-2 h**-1, or mm h**-1

    Variable: TP6H
    Description: 6-hour total precipitation
    Units: mm

    Variable: GWS10m
    Description: 10 metre gusty wind speed, defined as the larger value between
                 the analysed 10 metre wind speed and the 10 metre wind gust 
                 since previous post-processing in ERA5
    Units: m s**-1

    Variable: LTMT
    Description: Lower-tropospheric mean temperature based on the thickness 
                 between 500 and 1000 hPa
    Units: K

    Variable: T2m
    Description: 2 metre temperature directly extracted from ERA5
    Units: K

    Variable: MSLP
    Description: Mean sea level pressure directly extracted from ERA5
    Units: Pa

    Variable: ARS
    Description: Atmospheric river objects detected by the tARget-v3 algorithm,
                 with value of either 0 or 1 for the absence or the presence of
                 AR
    Units: none

    Variable: MARS
    Description: Atmospheric river objects detected by a modified version of 
                 the tARget-v3 algorithm (mtARget-v3), with value of either 0 
                 or 1 for the absence or the presence of AR
    Units: none

---------------------------------------------------------
WEBPAGE-SPECIFIC INFORMATION FOR: figs/yyyy_mm/index.html
---------------------------------------------------------

Purpose:
    This index.html file located in a monthly subfolder figs/yyyy_mm (e.g.,
    figs/2023_12/index.html) provides an interactive web browser-based tool for
    visualising the atmospheric river evolution on regional (North America) and
    global scales. 

Language: HTML

Access method and content:
    Click the figs folder and select a subfolder yyyy_mm (e.g., 2023_12),
    the index.html file should be loaded automatically to display a North 
    American map showing the atmospheric river shape boundaries (ARS) over
    the integrated water flux vector (Qu, Qv) and the integrated vapour
    transport IVT = sqrt(Qu*Qu + Qv*Qv). The backward (<<) and backward (>>)
    buttons can be used to step through the 6-hourly sequence through the
    month. Click the "Global" button will lead to an animatable display of 
    the global distributions of ARS (red dashed lines), MARS (blue solid
    lines), (Qu, Qv), IVT, and TPR. If the ARS contours are overlapped with
    MARS contours, they appear as red-blue lines.

Required image files:
    The displayed image over the North American domain is located in the "na" 
    subfolder (e.g., figs/2023_12/na/na_mtARget_v3_2023_12_01_0600_UTC.png). 
    Similarly, the image over the global domain is located in the "gb" domain
    (e.g., figs/2023_12/gb/gb_mtARget_v3_2023_12_01_0600_UTC.png).

---------------------------------------------------------------------
PROGRAM-SPECIFIC INFORMATION FOR: misc/Derive_variables_from_ERA5.py:
---------------------------------------------------------------------

Purpose:
    This python program demonstrates how to derive or extract variables for 
    atmospheric river analysis from the original ERA5 data. The derived 
    variables include Qu, Qv, IWV, CRH, TP6H, GWS10m, LTMT. The extracted
    variables include T2m and MSLP. It also derive ARS and MARS from two 
    outputs (out_202111.nc and mout_202111.nc) of a MATLAB program (mtarget.m).

Language: Python 3

Required libaries: numby, xarray, and metpy

Required data files: 
    misc/ERA5_sl_20211114_0000utc.nc
    misc/ERA5_pl_20211114_0000utc.nc
    misc/ERA5_hrly_tp_20211113.nc
    misc/ERA5_hrly_tp_20211114.nc
    misc/out_202111.nc
    misc/mout_202111.nc

Execution commands: python Derive_variables_from_ERA5.py

---------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/ERA5_sl_20211114_0000utc.nc
---------------------------------------------------------------

1. Source: ERA5 data on single levels valid at 0000 UTC 14 November 2021,
           downloaded from the C3S Climate Data Store 
           (https://doi.org/10.24381/cds.143582cf)
 
2. Number of variables: 17

3. Variable list:

    Variable: longitude
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: latitude
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: tcwv
    Description: Total column vertically-integrated water vapour, which can be
                 used to compare with the derived IWV given by the python 
                 program Derive_variables_from_ERA5.py
    Units: kg m**-2

    Variable: p71.162
    Description: Vertical integral of eastward water vapour flux, which can be
                 used to compare with the derived Qu given by the python
                 program Derive_variables_from_ERA5.py
    Units: kg m**-1 s**-1

    Variable: p72.162
    Description: Vertical integral of northward water vapour flux, which can be
                 used to compare with the derived Qv given by the python
                 program Derive_variables_from_ERA5.py
    Units: kg m**-1 s**-1

    Variable: u10
    Description: 10 metre eastward component of wind
    Units: m s**-1

    Variable: v10
    Description: 10 metre northward component of wind
    Units: m s**-1

    Variable: fg10
    Description: 10 metre wind gust since previous post-processing
    Units: m s**-1

    Variable: t2m (renamed T2m in data/era5dara_202111.nc)
    Description: 2 metre temperature
    Units: K

    Variable: d2m
    Description: 2 metre dewpoint temperature
    Units: K

    Variable: msl (renamed MSLP in data/era5dara_202111.nc)
    Description: Mean sea level pressure
    Units: Pa

    Variable: sp
    Description: Surface pressure
    Units: Pa 

    Variable: crr
    Description: Convective rain rate
    Units: kg m**-2 s**-1

    Variable: csfr
    Description: Convective snowfall rate water equivalent
    Units: kg m**-2 s**-1

    Variable: lsrr
    Description: Large scale rain rate
    Units: kg m**-2 s**-1

    Variable: lssfr
    Description: Large scale snowfall rate water equivalent
    Units: kg m**-2 s**-1

---------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/ERA5_pl_20211114_0000utc.nc
---------------------------------------------------------------

1. Source: ERA5 data on pressure levels valid at 0000 UTC 14 November 2021,
           downloaded from the C3S Climate Data Store 
           (https://doi.org/10.24381/cds.143582cf)

2. Number of variables: 9

3. Variable list:

    Variable: longitude
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: latitude
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: level
    Description: Pressure level
    Units: hPa

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: t
    Description: Air temperature
    Units: K

    Variable: z
    Description: Geopotential
    Units: m**2 s**-2

    Variable: q
    Description: Specific humidity
    Units: kg kg**-1

    Variable: u
    Description: Eastward component of wind
    Units: m s**-1

    Variable: v
    Description: Northward component of wind
    Units: m s**-1

---------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/ERA5_hrly_tp_20211113.nc
                               misc/ERA5_hrly_tp_20211114.nc
---------------------------------------------------------------

1. Source: ERA5 data (hourly total precipitation) on single levels for 
           13 & 14 November 2021, downloaded from the C3S Climate Data Store
           (https://doi.org/10.24381/cds.143582cf)

2. Number of variables: 4

3. Variable list:

    Variable: longitude
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: latitude
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: tp
    Description: Total precipitation (of the 1-hr period ending at the valid time)
    Units: m 

-------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/out_202111.nc
-------------------------------------------------

1. Source: This netCDF data file is the output of the MATLAB program mtarget.m 
           with key = 0. It includes 5 dimension variables and 52 data 
           variables. Only the data variable "shape" is used to create the ARS
           variable in this dataset (EDARA).

2. Number of variables: 57

3. Partial variable list:
 
    Variable: lon
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: lat
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: lev
    Description: A dimension variable with a default value 1, but could be 
                 re-used for a varying, non-regular dimension, such as forecast
                 step

    Variable: ens
    Description: Number of ensemble members, currently setting to 1
    
    Variable: shape 
    Description: Unique IDs for the atmospheric river objects detected by a
                 modified version of the tARget-v3 algorithm (mtARget-v3), 
                 with value being either na, or 1, 2, ...
    Units: none

--------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/mout_202111.nc
--------------------------------------------------

1. Source: This netCDF data file is the output of the MATLAB program mtarget.m
           with key = 1. It includes 5 dimension variables and 52 data
           variables. Only the data variable "shape" is used to create the 
           variable MARS in this dataset (EDARA).

2. Number of variables: 57

3. Partial variable list:

    Variable: lon
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: lat
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: lev
    Description: A dimension variable with a default value 1, but could be
                 re-used for a varying, non-regular dimension, such as forecast
                 step

    Variable: ens
    Description: Number of ensemble members, currently setting to 1

    Variable: shape
    Description: Unique IDs for the atmospheric river objects detected by a
                 modified version of the tARget-v3 algorithm (mtARget-v3),
                 with value being either na, or 1, 2, ...
    Units: none

--------------------------------------------------------------------------
PROGRAM-SPECIFIC INFORMATION FOR: misc/Extract_variables_from_era5dara.py:
--------------------------------------------------------------------------

Purpose:
    This python program demonstrates how to open a monthly dataset in the
    data folder and extract needed variables from it.

Language: Python 3

Required libaries: numby, xarray, and os

Required data files: data/era5dara_202111.nc

Execution commands: python Extract_variables_from_era5dara.py

------------------------------------------------
PROGRAM-SPECIFIC INFORMATION FOR: misc/mtarget.m 
------------------------------------------------

Purpose:
    This MATLAB program demonstrates how to execute the tARget-v3 algorithm and
    implement it for tracking atmospheric rivers globally. The original
    algorithm (tARget-v3) was developed by Guan and Waliser (2019). It can be
    executed by setting the first input parameter to 0. For the modified version 
    (mtARget-v3), the requirements on the direction of mean IVT are applied only
    over the tropical area (i.e., between 20°S and 20°N).

Language: MATLAB

Required libaries: image_toolbox, map_toolbox, and statistics_toolbox

Required data files: 
    misc/ERA5_ivt_tARget_202111.nc
    misc/ERA5_islnd.nc
    misc/ERA5_monthly_pixel_ivt_limit.nc

For the tARget-v3 algorithm (key = 0, output = 'out_202111.nc'):
  Execution command: matlab mtarget(0, 'ERA5_ivt_tARget_202111.nc', ...
                                    'ERA5_islnd.nc', 'ivtx','ivty',[],[],[], ...
                                    'out_202111.nc', ...
                                    'ERA5_monthly_pixel_ivt_limit.nc', ...
                                    100,2e6,2);

  Output: misc/out_202111.nc

For the mtARget-v3 algorithm (key = 1, output = 'mout_202111.nc'):
  Execution command: matlab mtarget(1, 'ERA5_ivt_tARget_202111.nc', ...
                                    'ERA5_islnd.nc', 'ivtx','ivty',[],[],[], ...
                                    'mout_202111.nc', ...
                                    'ERA5_monthly_pixel_ivt_limit.nc', ...
                                    100,2e6,2);

  Output: misc/mout_202111.nc

-------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/ERA5_ivt_tARget_202111.nc
-------------------------------------------------------------

1. Source: This is an input data file constructed from data/era5dara_202111.nc
           for the MATLAB program misc/mtarget.m. It includes 5 dimension 
           variables and 2 data variables.

2. Number of variables: 7

3. Variable list:

    Variable: lon
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: lat
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: lev
    Description: A dimension variable with a default value 1, but could be
                 re-used for a varying, non-regular dimension, such as forecast
                 step

    Variable: ens
    Description: Number of ensemble members, currently setting to 1

    Variable: ivtx (same as Qu in data/era5dara_202111.nc)
    Description: Vertical integral of eastward water vapour flux
    Units: kg m**-1 s**-1

    Variable: ivty (same as Qv in data/era5dara_202111.nc)
    Description: Vertical integral of northward water vapour flux
    Units: kg m**-1 s**-1

-------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/ERA5_islnd.nc
-------------------------------------------------

1. Source: This is an input data file constructed from the ERA5 land-sea
           mask for the MATLAB program misc/mtarget.m. It includes 5 dimension 
           variables and 1 data variable.

2. Number of variables: 6

3. Variable list:

    Variable: lon
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: lat
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Data type: datetime64[ns]

    Variable: lev
    Description: A dimension variable with a default value 1, but could be
                 re-used for a varying, non-regular dimension, such as forecast
                 step

    Variable: ens
    Description: Number of ensemble members, currently setting to 1

    Variable: islnd
    Description: A land-sea mask parameter containing 1 over land and 0 over
                 ocean
    Units: none 

-------------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: misc/ERA5_monthly_pixel_ivt_limit.nc
-------------------------------------------------------------------

1. Source: This is an input data file constructed from data/era5dara_yyyymm.nc
           for the MATLAB program misc/mtarget.m. It contains monthly IVT
           percentile information based on a 30-year (1991-2020) climatology.

2. Notes: This file cannot be correctly opened with xarray in a python program.
          Use the netCDF4 libary instead, e.g., netCDF4.Dataset().

3. Number of variables: 6

4. Variable list:

    Variable: lon
    Description: Longitudes of the data grids
    Units: degrees east

    Variable: lat
    Description: Latitudes of the data grids
    Units: degrees north

    Variable: time
    Description: Valid time
    Units: Months since 0001-01-01 00:00:00

    Variable: lev
    Description: A dimension variable with a default value 1, but could be
                 re-used for a varying, non-regular dimension, such as forecast
                 step

    Variable: ens
    Description: Number of ensemble members, currently setting to 1

    Variable: ivt1
    Description: IVT 85th percentile
    Units: kg m^-1 s^-1

    Variable: ivt2
    Description: IVT 87.5th percentile
    Units: kg m^-1 s^-1

    Variable: ivt3
    Description: IVT 90th percentile
    Units: kg m^-1 s^-1

    Variable: ivt4
    Description: IVT 92.5th percentile
    Units: kg m^-1 s^-1

    Variable: ivt5
    Description: IVT 95th percentile
    Units: kg m^-1 s^-1

END
