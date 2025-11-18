This README.txt file was generated on 2025-03-03 by T.-C. Chen and A. Di Luca

--------------------
GENERAL INFORMATION
--------------------


1-Title of the dataset: Precipitation and 10m wind speed extreme exceedances from ERA5, IMERG and ISD and their association with cyclones over North America.

2-Authors Information: Ting-Chen Chen1,2 and Alejandro Di Luca1

3-Affiliation: 
	1 Centre pour l’Étude et la simulation du climat à l’échelle régionale (ESCER) | Département des sciences de la Terre et de l’atmosphère. Université du Québec à Montréal (UQAM), Montréal, Canada. 
	2 Moody's Corporation (United States)

4- Information about funding sources that supported the collection of the data:

This research has been made as part of the project “Simulation et analyse du climat à haute résolution” thanks to the financial participation of the Government of Québec. This research was enabled in part by support provided by Calcul Québec (https://www.calculquebec.ca) and the Digital Research Alliance of Canada (https://alliancecan.ca). 

A. Di Luca was funded by the Natural Sciences and Engineering Research Council of Canada (NSERC) grant (RGPIN-2020-05631). 


--------------------------------------------------
SHARING/ACCESS INFORMATION
--------------------------------------------------

1-Licenses/Restrictions placed on the data: 
These data are available under a CC BY 4.0 license <https://creativecommons.org/licenses/by/4.0/> 

2- Links to publications that cite or use the data: 
Chen, T.-C. and A. Di Luca. Characteristics of Precipitation and Wind Extremes Induced
by Extratropical Cyclones in Northeastern North America. JGR-Atmospheres. 10.1029/2024JD042079

3-Recommended citation for this dataset:
Chen, T.-C. And A. Di Luca (2025). Precipitation and 10m wind speed extreme exceedances from ERA5, IMERG and ISD and their association with cyclones over North America. Federated Research Data Repository. 10.20383/103.01231


-----------------------------
DATA & FILE OVERVIEW
-----------------------------

1-File list (43 files):
   Documentation file (1 file): 
        -README.txt
   Data directories and files (for a total of 42 files):
	-directory Data_For_Figures (37 files, 3.5 GB):
		•Topography: Geopotential_orography.nc

		•Local extreme thresholds: 
			WSp99p0_2001_2020_ERA5.nc
			TPp99p0_2001_2020_ERA5.nc
			TPp99p0_2001_2020_IMERG.nc 
			TPp99p0_2001_2020_IMERG025grid.nc
			WSnTPp99p0_exthreshold_ISD.nc4

		•Averaged local exceedance: 
			Averaged_exceedance_WS_p99p0_ERA5.nc
			Averaged_exceedance_TP_p99p0_ERA5.nc
			Averaged_exceedance_TP_p99p0_IMERG.nc

		•ISD post-processed extreme data: 
			ISD_extremes_p99p0.nc4
			ERA5_regridded_ISDstation_WS_p99p0.nc4
			ERA5_regridded_ISDstation_TP_p99p0.nc4
			IMERG_regridded_ISDstation_TP_p99p0.nc4

		•Extremes associated with ETCs: 
			WSExtremes_p99p0_ETC_association_2001_2020_ERA5.nc
			TPExtremes_p99p0_ETC_association_2001_2020_ERA5.nc
			TPExtremes_p99p0_ETC_association_2001_2020_IMERG.nc

		•Compound extremes:
			CompoundExtremes_p98p0_ETC_association_relaxto12h_2001_2020_ERA5.nc
			CompoundExtremes_p99p0_ETC_association_relaxto12h_2001_2020_ERA5.nc
			CompoundExtremes_p99p9_ETC_association_relaxto12h_2001_2020_ERA5.nc

		•Case study of 2019 Halloween Storm:
			HalloweenStorm_track.txt
			WSExtremes_p99p0_duration_exceedance_distribution_Halloween_ERA5.nc
			TPExtremes_p99p0_duration_exceedance_distribution_Halloween_ERA5.nc
			TPExtremes_p99p0_duration_exceedance_distribution_Halloween_IMERG.nc
			Timeseries_WSnTP_local_record_Montreal_2019HalloweenStorm.nc
			ERA5_2019OctNov_TP_10mUV.nc
			ERA5_2019OctNov_mslp.nc

		•Exceedance distribution as a function of extreme duration:
			PDF_WSexceedance_duration_p98p0_NNA_ERA5.txt
			PDF_WSexceedance_duration_p99p0_NNA_ERA5.txt
			PDF_WSexceedance_duration_p99p9_NNA_ERA5.txt
			PDF_TPexceedance_duration_p98p0_NNA_ERA5.txt
			PDF_TPexceedance_duration_p99p0_NNA_ERA5.txt
			PDF_TPexceedance_duration_p99p9_NNA_ERA5.txt
			PDF_TPexceedance_duration_p98p0_NNA_IMERG.txt
			PDF_TPexceedance_duration_p99p0_NNA_IMERG.txt
			PDF_TPexceedance_duration_p99p9_NNA_IMERG.txt

		•Storm lists (and associated WS & TP exceedance in NNA):
			Stormlist_inNNA_2001_2020_exceedance_WDp99p0_TPp99p0_timeavg.txt
			Stormlist_inNNA_2001_2020_exceedance_WDp99p0_TPp99p0_timecum.txt

    -directory Data_ForOrFrom_Analysis (5 files, 14 GB):
		•Complete ETC tracks (raw output from the algorithm, no extreme information):
            ETC_identified_n_tracking_output_2000_2020.txt
            
		•Deatiled records of local extreme occurrences (time, value, and ETC association):
            PrecExtremes_p99p0valtimeETC_2001_2020_ERA5.nc
		    WindExtremes_p99p0valtimeETC_2001_2020_ERA5.n
		    PrecExtremes_p99p0valtimeETC_2001_2020_IMERG.nc

		•Counts of compound extreme occurrences in four seasons:
            CompoundExtremes_p99p0_ETC_association_relaxto12h_2001_2020_ERA5.nc


Some of the acronyms used in file naming are listed below, but please refer to Chen and Di Luca (2025) for other definitions.
-WS refers to 10-m Wind Speeds.
-TP refers to total surface precipitation.
-P98p0 refers to extremes defined using the 98.0 percentile.
-P99p0 refers to extremes defined using the 99.0 percentile.
-P99p9 refers to extremes defined using the 99.9 percentile.
-ERA5 refers to calculations made using ERA5 reanalysis data.
-IMERG refers to calculations made using IMERG satellite-based data.
-NNA refers to the Northeast North American region.
-Compound extremes refer to extremes showing simultaneously wind AND precipitation extremes within a 12h window.
-timeavg refers to storm extremes calculated using the average Extreme Exceedance metric.
-timecum refers to storm extremes calculated using the cumulated Extreme Exceedance metric.


2-Files format: files are provided either in netCDF format, or Network Common Data Form, a binary file format that stores scientific data (https://www.unidata.ucar.edu/software/netcdf/) or in text format (*.txt). All the scripts needed for the analysis and visualization of the data are provided in a zenodo repository (Chen and Di Luca, 2025). Scripts are written using of both Fortran and Python programming languages. 

3- Files content: see below for specific description of each file.


--------------------------
METHODOLOGICAL INFORMATION
--------------------------

1-Description of methods used for collection/generation of data:
The dataset includes files that are needed to calculate precipitation and 10m wind speed extremes from ERA5 reanalysis data (Hersbach et al., 2020), the IMERG satellite-based data (Huffman et al., 2019) and the ISD2ERA5 data (Collet et al., 2022), and their association with extratropical cyclones (ETCs) over North America (Chen et al., 2022). Extremes are based on the calculation of the extreme exceedance (EE) based on high percentiles values (98th, 99th and 99.9th) and two derived metrics: the time-average EE and the time-cumulated EE (Chen and Di Luca, 2025). In addition extreme exceedances are calculated for individual ETC events over North American, although with a focus over Northeastern North America (NNA). A detailed description of these calculations is provided in the methodology section of Chen and Di Luca (2025a). The files provided in this catalog can be used with the code in Chen and Di Luca (2025b) to a permit the calculation of all the results presented in Chen and Di Luca (2025a).

2-Bibliographic references and hyperlinks to publications related to this dataset:
 - Chen, T.-C., Di Luca, A., Winger, K., 2022. North America Extratropical Cyclone (NAEC) Catalogue [Dataset].
Borealis. https://doi.org/10.5683/SP3/LH8OBV
 - Chen T.-C. and A. Di Luca (2025). "Characteristics of Precipitation and Wind Extremes Induced by Extratropical Cyclones in Northeastern North America". Journal of Geophysical Research - Atmosphere.
 - Chen, T.-C., and Di Luca, A. (2025). ETC-induced Precipitation and Wind Extremes Analysis (v0.1.0). Zenodo. https://doi.org/10.5281/zenodo.14976915
 - Collet, F., Di Luca, A., Chen, T.-C., 2022. North America ISD to ERA5 (NA-ISD2ERA) Catalogue V1
[Dataset]. Borealis. https://doi.org/10.5683/SP3/LWMGRM
 - Hersbach, H., Bell, B., Berrisford, P., Hirahara, S., Horányi, A., Muñoz‐Sabater, J., Nicolas, J., Peubey, C.,
Radu, R., Schepers, D., Simmons, A., Soci, C., Abdalla, S., Abellan, X., Balsamo, G., Bechtold, P., Biavati, G., Bidlot, J., Bonavita, M., De Chiara, G., Dahlgren, P., Dee, D., Diamantakis, M., Dragani, R., Flemming, J., Forbes, R., Fuentes, M., Geer, A., Haimberger, L., Healy, S., Hogan, R.J., Hólm, E., Janisková, M., Keeley, S., Laloyaux, P., Lopez, P., Lupu, C., Radnoti, G., de Rosnay, P., Rozum, I., Vamborg, F., Villaume, S., Thépaut, J., 2020. The ERA5 global reanalysis. Quarterly Journal of the Royal Meteorological Society 146, 1999–2049. https://doi.org/10.1002/qj.3803
 - Huffman, G.J., Stocker, E.F., Bolvin, D.T., Nelkin, E.J., Tan, J., 2019. GPM IMERG Final Precipitation L3 Half Hourly 0.1 degree x 0.1 degree V06 [Dataset]. https://doi.org/10.5067/GPM/IMERG/3B-HH/06 (access: 10.30.2021)

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILE: Geopotential_orography.nc
--------------------------

1-Variables: Geopotential height of the surface (m2 s-2).
2-Frequency: invariable
3-Period of availability: -
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: [var]p99p0_2001_2020_ERA5.nc
--------------------------
var is either 10-m wind speed (WS) or surface precipitation (TP)
99.0 percentile from ERA5 reanalysis data

1-Variables: 10-m wind speed (WS) and surface precipitation (TP)
2-Frequency: climatological annual value
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: TPp99p0_2001_2020_IMERG.nc
--------------------------
99.0 percentile from IMERG data

1-Variables: surface precipitation (TP)
2-Frequency: climatological annual value
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.1 deg
5-Domain extent: North American domain
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: TPp99p0_2001_2020_IMERG025GRID.nc
--------------------------
99.0 percentile from IMERG data, interpolated conservatively to the ERA5 grid

1-Variables: surface precipitation (TP)
2-Frequency: climatological annual value
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: WSnTPp99p0_exthreshold_ISD.nc4
--------------------------
99.0 percentile from ISD2ERA5 data

1-Variables: 10-m wind speed (WS) and surface precipitation (TP)
2-Frequency: climatological annual value
3-Period of availability: 2001-2020
4-Horizontal grid spacing: grid point
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: Averaged_exceedance_[var]_p99p0_[data source].nc
--------------------------
data source is either ERA5 reanalysis or IMERG

1-Variables: 10-m wind speed (WS) and surface precipitation (TP)
2-Frequency: seasonal (DJF, MAM, JJA, SON)
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: [var]Extremes_p99p0_ETC_association_2001_2020_[data source].nc
--------------------------
data source is either ERA5 reanalysis or IMERG

1-Variables: Prob_Extreme_ass_ETC, Prob_Extreme_ass_ETC_sea, Extreme_cases_sea, Extremevalues_total_sea, Extremevalues_ETC_sea
2-Frequency: seasonal (DJF, MAM, JJA, SON)
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg or 0.1 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: CompoundExtremes_[percentile]_ETC_association_relaxto12h_2001_2020_ERA5.nc
--------------------------
percentile is either p98p0, p99p0 or p99p9 from ERA5 reanalysis data.

1-Variables: ETC_Compound_counts_12h, noETC_Compound_counts_12h
2-Frequency: seasonal (DJF, MAM, JJA, SON)
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: PDF_[var]exceedance_duration_[percentile]_NNA_[data source].txt
--------------------------
percentile is either p98p0, p99p0 or p99p9 from ERA5 reanalysis data.
data source is either ERA5 reanalysis or IMERG
var is either 10-m wind speed (WS) or surface precipitation (TP)

1-Variables: 3 columns (from left to right): (1) probability density functions (PDF) of extreme duration (each line/bin increases by 1 hour), (2) averaged exeedance (intensity) as a function of duration (each line/bin increases by 1 hour), (3) PDF of extreme exeedance (each line/bin increases by 0.2 mm/hr)
2-Frequency: -
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg or 0.1 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: Stormlist_inNNA_2001_2020_exceedance_WDp99p0_TPp99p0_[metric].txt
--------------------------
Extreme metrics are either timeavg (time average) or timecum (time cumulated)

1-Variables: 7 columns (from left to right): (1) Storm number, (2) Storm peak intensity (pmin), (3) Storm peak intensity (vors), (4) WS extreme exceedance, (5) TP extreme exceedance, (6) WS extreme area (number of grid points with at least one extreme in the ETC's entire lifetime), (7) TP extreme area (number of grid points with at least one extreme in the ETC's entire lifetime)
2-Frequency: -
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: -

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILE: ETC_identified_n_tracking_output_2000_2020.txt
--------------------------
Data similar to the one publihsed in the NAEC catalog.

1-Variables: multiple characteristics of storms identified in North America 
2-Frequency: hourly (Lagrangian; following each ETC track)
3-Period of availability: 2000-2020
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: 

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILES: [var]Extremes_p99p0valtimeETC_2001_2020_[data source].nc
--------------------------
data source is either ERA5 reanalysis or IMERG
Var is either 10-m wind speed (Wind) or surface precipitation (Prec)

1-Variables: Extreme_values, Extreme_time, ETC_presence (=1 indicates the extreme is associated with one or more ETCs in 1000 km; =0 otherwise)
2-Frequency: hourly (only recorded when the local extreme occurrs)
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg or 0.1 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: 

-------------------------- 
DATA-SPECIFIC INFORMATION FOR FILE: CompoundExtremes_p99p0_ETC_association_relaxto12h_2001_2020_ERA5.nc
--------------------------
data source is ERA5 reanalysis 
Compound metric is based on 10-m wind speed (Wind) and surface precipitation (Prec)

1-Variables: ETC_Compound_counts_12h, noETC_Compound_counts_12h
2-Frequency: seasonal (DJF, MAM, JJA, SON)
3-Period of availability: 2001-2020
4-Horizontal grid spacing: 0.25 deg
5-Domain extent: North American domain (20 W-150 W; 25 N-75 N)
6-Data production date: 