This GUY_README.txt file was generated on 2025-10-20 by Gifty Attiah

--------------------
GENERAL INFORMATION
--------------------

1. Title of Dataset: High-Resolution (1 km) Daily Climate Reanalysis Dataset for Guyana (1950–2024)

2. Author Information
	 

	A. 	Name: Bhaleka Persaud
		Institution:  University of Waterloo
		Email: bd2persa@uwaterloo.ca
		
	B.	Name: Gifty Attiah
		Institution:  Wilfrid Laurier University
		Email: gattiah@wlu.ca

	C. 	Name: Michelle Kalamandeen
		Institution:  Unique land use GmbH, Schnewlinstraße 10, 79098 Freiburg im Breisgau, Germany
		Email: 

	D. 	Name: Ali Reza Shahvaran
		Institution:  University of Waterloo
		Email: alireza.shahvaran@uwaterloo.ca

	E. 	Name:  Jovana Radosavljevic
		Institution:  University of Waterloo
		Email: jovana.radosavljevic@uwaterloo.ca

			
	F. 	Name: Lyndon Alves
		Institution:  Guyana Civil Aviation Authority, Guyana
		Email: lyndonalves26@gmail.com

	G. 	Name: Esan Hamer
		Institution: University of Guyana
		Email: esan.hamer@uog.edu.gy

	H. 	Name: Gyanpriya Maharaj
		Institution: University of Guyana
		Email: gyanpriya.maharaj@uog.edu.gy

	H. 	Name: Romario D. Hastings​
		Institution:  Kako Indigenous Community, Region 8, Guyana
		Email: romario_hastings@yahoo.com

	J. 	Name: Homa K. Pour
		Institution:  Wilfrid Laurier University
		Email: hpour@wlu.ca

	K. 	Name: Philippe Van Cappellen
		Institution:  University of Waterloo
		Email: pvc@uwaterloo.ca
		



3. Date of data collection (single date, range, approximate date): 1980-01-01: 2024-12-31

4. Geographic location of data collection: Guyana, South America: West Longitude:-62.0, East Longitude:-56.0, North Latitude: 8.5, South Latitude: 1.18


5. Information about funding sources that supported the collection of the data: 

Canada First Research Excellence Fund: Global Water Futures
Canada Foundation for Innovation (CFI) Major Science Initiatives (MSI) Fund: Global Water Futures Observatories

---------------------------
SHARING/ACCESS INFORMATION
---------------------------

1. Licenses/restrictions placed on the data: 

These data are available under a CC BY 4.0 license <https://creativecommons.org/licenses/by/4.0/> 

2. Links to publications that cite or use the data: 

3. Links/relationships to ancillary data sets or software packages: 

ERA5 Land data on single levels from 1940 to present: https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-era5-single-levels?tab=overview
www.ogimet.com and https://www.ncei.noaa.gov/pub/data/ghcn/daily/readme.txt and Public Weather forecast issued by Hydrometeorological Service in Guyana

5. Was data derived from another source? Yes it was re gridded from ERA5 data to 1km over Guyana

6. Recommended citation for this dataset: 

Persaud, B.,Attiah, G. Kalamandeen, M., Shahvaran, A. R., Radosavljevic, J., Alves, L., Hamer, E., Maharaj, G., Hastings, R., Pour, H. K., & Van Cappellen, P. (2025). High-Resolution (1 km) Daily Climate Reanalysis Dataset for Guyana (1950–2024). Federated Research Data Repository. https://doi.org/10.20383/103.01185

---------------------
DATA & FILE OVERVIEW
---------------------

1. File List

Data contains Air temperature and Total Precipitation over Guyana

   A. Folder name: 2m_Air_Temperature  
      Short description: The folder contains daily 2 m air temperature data for Guyana (1950–2024) regridded from ERA5. The data are stored in NetCDF files, grouped by year and month.

   B. Folder name: Total_Precipitation     
      Short description: The folder contains daily total precipitation for Guyana (1950–2024) regridded from ERA5. The data are stored in NetCDF files, grouped by year and month.   
   
  C. Folder name:  Validation Data
       Description: Remote Sensed Data  (Maximum Air temperature, Minimum Air temperature and Total Precipitation) over Guyana from 1981 to 2024. The daily data are stored in TIFF files, group by day


2. Relationship between files, if important: Folder C contains the remote sensed data, while Folders A and B contains are regridded 1km data using ERA5. 

3. Additional related data collected that was not included in the current data package: 

4. Are there multiple versions of the dataset? no


---------------------------
METHODOLOGICAL INFORMATION
---------------------------

1. Description of methods used for collection/generation of data: 
Daily mean 2 m air temperature and total precipitation data from (European Centre for Medium-Range Weather Forecasts Reanalysis v5 ECMWF (ERA5) ERA5-Land were obtained and pre-processed using Google Earth Engine (GEE) for the period 1950–2024. The spatial subset corresponding to Guyana was extracted based on a polygon shapefile delineating the country’s boundaries. To improve spatial detail, the native 9 km resolution data were resampled to a 1 km grid through the nearest-neighbour interpolation technique. Temperature and precipitation values, originally expressed in Kelvin (K) and meters (m), were converted to Celsius (°C) and millimetres (mm) to ensure consistency with ground-based observations.



The "Validation_data" folder contains three directory that daily GeoTIFF rasters used exclusively to validate the Guyana 1-km ERA5-Land regridded dataset against independent satellite–gauge products. Specifically, it includes (i) CHIRPS daily precipitation files named "CHIRPS_precipitation_YYYY-MM-DD.tif" covering 1981-01-01 to 2024-12-31 (units: mm day⁻¹), and (ii) CHIRTS daily air-temperature files named "CHIRTS_maximum_temperature_YYYY-MM-DD.tif" and "CHIRTS_minimum_temperature_YYYY-MM-DD.tif" covering 1983-01-01 to 2016-12-31 (units: °C). All rasters were programmatically retrieved from Google Earth Engine collections ("UCSB-CHG/CHIRPS/DAILY" and "UCSB-CHG/CHIRTS/DAILY"), exported in EPSG:4326, clipped to the national boundary of Guyana, and (for analysis) standardized to a common ~5 km grid (≈0.045°) using bilinear resampling to support like-for-like comparison with ERA5-derived fields. These layers served as inputs for point-based matchups on a 5-km analysis grid and for subsequent Pearson/Spearman correlation and summary-statistic calculations reported in the manuscript. File naming is strictly date-stamped (YYYY-MM-DD) and variable-explicit to support automated ingestion. Together, these CHIRPS/CHIRTS tiles provide an openly documented, third-party benchmark for spatial and temporal cross-validation of precipitation and temperature patterns across Guyana.

2. Methods for processing the data: 
Data was stored and processed on the Graham clusters on Compute Canada using python 3.7.8.   

3. Instrument- or software-specific information needed to interpret the data: 
ArcGIS Map 10.8, ArcGIS Pro, Panopoly, Python 3.7.8, R software

4. Standards and calibration information, if appropriate: 

5. Environmental/experimental conditions: 

6. Describe any quality-assurance procedures performed on the data:
 
Dataset was plotted and checked.

7. People involved with sample collection, processing, analysis and/or submission: 
Gifty Attiah
Bhaleka Persaud
Shahvaran, A. R.



