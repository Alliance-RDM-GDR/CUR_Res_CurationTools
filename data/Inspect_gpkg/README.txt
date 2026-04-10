This README.txt file was generated on 2024-07-11 by Isabelle Lefebvre

--------------------
GENERAL INFORMATION
--------------------

1. Title of Dataset: UAV LiDAR, UAV Imagery, Tree Segmentations and Ground Mesurements for Estimating Tree Biomass in Canadian (Quebec) Plantations

2. Author Information
	A. Project Lead Contact Information
		Name: Isabelle Lefebvre
		Institution: Université de Montréal 
		Email: isabelle.lefebvre.11@umontreal.ca

	B. Principal Investigator Contact Information
		Name: Etienne Laliberté
		Institution:  Université de Montréal
		Email: etienne.laliberte@umontreal.ca


3. Date of data collection : 
	From 2023-06-05 to 2023-10-14

4. Geographic location of data collection:
  	Métabetchouan-Lac-à-la-Croix, Saguenay Lac-Saint-Jean, Québec, Canada
	Stratford, Estrie, Québec, Canada
  	Saint-Adrien, Estrie, Québec, Canada
   	Ham-Nord, Centre-du-Québec, Québec, Canada


5. Information about funding sources that supported the collection of the data: 
	Canada First Research Excellence Fund (to the Institute for Data Valorisation (IVADO)) PRF-2021-02
	Natural Science and Engineering Research Council of Canada (NSERC), Fundamental drivers of plant spectral diversity, Discovery Grant program RGPIN-2019-04537
	Natural Science and Engineering Research Council of Canada (NSERC), Canada Research Chair in Plant Functional Biodiversity, Canada research chairs 950-231858

---------------------------
SHARING/ACCESS INFORMATION
---------------------------

1. Licenses/restrictions placed on the data: 
   	These data are available under a CC0 1.0 license <https://creativecommons.org/publicdomain/zero/1.0/> 

2. Was data derived from another source? yes/no
	No

3. Recommended citation for this dataset: 
   	FRDR recommends a citation similar to: 
   	Lefebvre,Isabelle.,Laliberté,Etienne. (2024). UAV LiDAR, UAV Imagery and Ground Measurements for Estimating Tree Biomass in Canadian (Quebec) Plantations. Federated Research Data Repository. doi: 10.20383/103.0979

---------------------
DATA & FILE OVERVIEW
---------------------

1. File List

   A. Foldername: Vector_Data      
      Description:  Contains a geopackage (.gpkg) for each drone mission. Each geopackage has two layers: a point layer with tree measurements and a polygon layer with hand made tree crown segmentation.     

   B. Foldername:  LiDAR     
      Description: Contains LiDAR point clouds (.laz).      

   C. Foldername: Photogrammetry_Data      
      Description: Each subfolder contains metashape products for a drone mission (orthomosaic (.tif), photogrammetric point cloud (.laz), digital surface model (.tif) and processing report (.pdf).


2. Relationship between files, if important:
	Each subfolder name has a mission ID following the format: <yyyymmdd>_<site>_<optional mission qualifier>_<instrument>
	All files related to the mission will contain that mission ID.

3. Additional related data collected that was not included in the current data package: 
	Raw Zenmuse P1 images
	Raw Zenmuse L1 files
	Ground control points positions
	
---------------------------
METHODOLOGICAL INFORMATION
---------------------------

1. Description of methods used for collection/generation of data: 

	Tree measurements

	Trees were sampled in Carbone Boréal's permanent plots. These are circular plots with a radius of 5.64 m. In these plots, the height and diameter at 1.3 meters above the ground (DBH) of all trees were measured. 
	Heights were measured at two different points: total height at the tree tops and another height excluding the annual apical growth. The DBH was measured for trees with a total height greater than 1.3 meters. 
	For trees with a total height less than 1.3 meters, the diameter at stump height (DSH), measured 15 cm from the ground, was measured instead. 
	Height and DBH/DSH measurements were taken three times independently by different people. For each measured tree or shrub, the species, or genus was recorded. 
	The trees were also georeferenced using a combination of the orthomosaic generated from drone imagery and a submeter-accuracy GNSS Arrow 100 receiver.

	Due to the absence of permanent plots and to evaluate the error for trees measured in Compensation CO2 Québec plantations, the methodology described for the Carbone Boréal plots was repeated for a subsample of 212 trees in Estrie.

	To complete the dataset, other scattered trees in the plantations were measured. These trees outside the plots were measured only once, and only the maximum height and DBH/DSH were recorded.

	Drone Flights

	For each area, at least two missions were conducted: the first to collect RGB images and the second for LiDAR data. 
	The missions were performed using the DJI Matrice 300 RTK equipped with a DJI Zenmuse P1 camera for RGB data and a DJI Zenmuse L1 sensor for LiDAR. 
	The RGB missions were flown at a height of 40 m above the DSM to obtain a GSD of 0.5 cm/pixel, with a speed of 5.3 m/s, 70% side overlap, and 85% front overlap. 
	The LiDAR missions were flown at a height of 50 m above the DSM, with a speed of 5 m/s, 70% flight line overlap, repetitive scan mode, a sampling rate of 240 kHz, and dual returns, resulting in a point cloud density of 1,738 points/m2. 
	For precise georeferencing, the base position and a minimum of four control points per mission were measured using an Emlid GNSS receiver connected to the RTK Can-Net network, achieving centimeter accuracy. 

	Two RGB missions located in Estrie in the CO2 plantations were repeated on three different dates following the mentioned methodology. 
	Additionally, these same missions were also captured with a DJI Mavic Mini 2 and a DJI Mini 3 Pro. Missions with the Mini 2 were flown at heights of 10 and 30 m to obtain respective GSDs of 0.35 and 1.05 cm/pixel. 
	Missions with the  DJI Mini 3 Pro were flown at heights of 20 and 30 m above ground level (AGL) to obtain respective GSDs of 0.36 and 0.53 cm/pixel. All missions with the Mini 2 and Mini 3 Pro had a 90% side overlap and 70% front overlap. 

2. Methods for processing the data: 

	The RGB photos were processed using Agisoft Metashape 2.1.0 software to generate the photogrammetric point cloud, the digital surface model (DSM), and the orthomosaic for each mission. 
	The photogrammetric point cloud was generated with high accuracy and filtering disabled. The DSM was generated from that point cloud. The orthomosaic was generated from a medium-density point cloud with aggressive filtering. 
	The georeferencing of these products was adjusted, if necessary, using the control points. 
	The final products include the  high-density point clouds, DSM with a resolution of about 1 cm/pixel, and orthomosaics with a resolution of 0.5 cm/pixel for each mission using the Zenmuse P1 camera. 
	Note that, for the DJI Mini 2 and Mini 3 Pro drones, orthomosaic resolutions ranges between 0.3 and 1.1 cm/pixel. The georeferencing error of each product ranges between 5 and 10 cm.

	The LiDAR data was processed using the free version of DJI Terra 3.5.0 software to obtain point clouds. As with the RGB data, georeferencing was done using the base and the drone's RTK positioning. 
	However, ground control points were not used for this data. The L1 sensor is expected to have a vertical accuracy of 5 cm and a horizontal accuracy of 10 cm when used at a height of 50 m with a UAV receiving RTK corrections. 


3. Environmental/experimental conditions:
	The data was collected from tree plantations for the voluntary carbon market.
	These plantations, located in Quebec, Canada, are managed by Carbone Boréal in the administrative region of Saguenay-Lac-Saint-Jean and by Compensation CO2 Québec in Estrie and Centre-du-Québec.

	Carbone Boréal Plantations

	The Carbone Boréal plantations are located in sections of fallow or non-arable agricultural land due to various reasons, including the terrain. 
	These plantations were planted in 2013. The sites contain five conifer and four hardwood species.
	The different sites are surrounded by agricultural land and small wooded areas. There are steep slopes, hills, and streams. 
	The soil is generally dominated by herbaceous plants, mostly grasses. In addition to the planted species, several tree and shrub species have managed to establish themselves within the plantations.

	Compensation CO2 Québec Plantations

	The three Compensation CO2 Québec plantations that were sampled are also located on portions of fallow or non-productive land. 
	On these sites, planting operations were carried out between 2011 and 2016. Four species were planted on these sites, including three conifer species and one hardwood species.
	However, the majority of the plantations consist of white spruce. The plantations are surrounded by agricultural fields, mature plantations, and natural forests, and the terrain is generally flat or gently sloping.
	There are few other tree and shrub species naturally established. However, the soil is dominated by tall herbaceous plants such as grasses and goldenrod.
 

4. Describe any quality-assurance procedures performed on the data: 
	Visual examination of DSMs and orthomosaics on ArcGIS Pro
	Visual examination of polygons on ArcGIS Pro
	Cleaning of polygons (removing invalid polygons, superfluous sections of multipolygons, keeping only one polygon per tree) using Python
	Visual examination of points to ensure they are all overlaid on a tree and within that tree's polygon, if applicable
	Examination of abnormal height / DBH data. Correct when possible, otherwise remove or note (in the comments section)

5. People involved with sample collection, processing, analysis and/or submission: 
	Isabelle Lefebvre
	Etienne Laliberté
	Antoine Caron-Guay
	Anne-Marie Cousineau
	Chloé Fiset
	Mélisande Teng
	Vincent Le Falher
	Sabrina Demers-Thibeault
	

-----------------------------------------------------------------
DATA-SPECIFIC INFORMATION FOR: /Vector_data, point layers
-----------------------------------------------------------------
Please note that the /vector_data folder contains the geopackages.
Each geopackage includes a layer with the points and a layer with the polygons associated with a drone mission.
Their boundaries correspond to those of the missions contained in /metashape_products.

DATA-SPECIFIC INFORMATION FOR: point layers

1. Number of variables: 19

2. Missing data codes:
        NA        missing data

3. Variable List:

    A.	Name: plot
	Description: Plot or zone number to which the points belong. All points measured three times, and only these, have an associated value.

    B.	Name: class_code
	Description: Four-letter unique code for each species/genus.

    C.	Name: scientific_name
	Description: Scientific name. Trees are identified to the species or genus when identification to the species is not possible. Identified in the field.

    D.	Name: taxon_id
	Description: Link to the GBIF identifier associated with each species.

    E.	Name: planted_natural
	Description: Binary value: "planted" if the tree was planted by Carbone Boréal or "natural" if the tree was established naturally.

    F.	Name: instrument
	Description: Indicates which instrument was used to measure the tree height. It can be "tape" (measuring tape) or "laser".

    G.	Name: height1_no_shoot_cm
	Description: Tree height measured from the base to the last branch junction identifying the annual apical shoot. All these measurements were taken by the same person. Noted in centimeters.

    H.	Name: height2_no_shoot_cm
	Description: Tree height measured from the base to the last junction identifying the annual apical shoot. All these measurements were taken by the same person. Noted in centimeters.

    I.	Name: height3_no_shoot_cm 
	Description: Tree height measured from the base to the last junction identifying the annual apical shoot. All these measurements were taken by the same person. Noted in centimeters.

    J.	Name: total_height1_cm
	Description: Total tree height measured from the base of the tree to the highest point. Noted in centimeters.

    K.	Name: total_height2_cm
	Description: Total tree height measured from the base of the tree to the highest point. Noted in centimeters.

    L.	Name: total_height3_cm
	Description: Total tree height measured from the base of the tree to the highest point. Noted in centimeters.

    M.	Name: diameter_type
	Description: Indicates whether dbh or dsh was measured. "dbh" for diameter at breast height, a standard measure taken at 1.3m from the base of the tree. "dsh" for diameter at stump height, a standard measure generally for trees less than 1.3m tall and measured at 15 cm from the base of the tree.

    N.	Name: diameter1_mm
	Description: Value of dbh or dsh measured in mm using a caliper (some trees measured using a digital caliper).

    O.	Name: diameter2_mm
	Description: Value of dbh or dsh measured in mm using a caliper (some trees measured using a digital caliper). Only for trees measured three times.

    P.	Name: diameter3_mm
	Description: Value of dbh or dsh measured in mm using a caliper (some trees measured using a digital caliper). Only for trees measured three times.

    Q.	Name: comments
	Description: Comments to note irregularities encountered during field measurements.

    R.	Name: date_measured
	Description: Date and time of the measurement as recorded by ArcGIS Field Maps.

    S.	Name: geom
	Description: Geographical coordinates in WSG84 UTM zone 19N. Measured with an Arrow 100 and confirmed with the orthomosaic.




DATA-SPECIFIC INFORMATION FOR: polygon layers

1. Number of variables: 4

2. Missing data codes:
        NA        missing data
     
3. Variable List:

    A.	Name: scientific_name
	Description: Scientific name. Trees are identified to the species or genus when identification to the species is not possible. Determined by photo interpretation.

    B.	Name: class_code
	Description: Four-letter unique code for each species/genus.

    C.	Name: taxon_id
	Description: Link to the GBIF identifier associated with each species.

    D.	Name: geom
	Description: Polygon coordinates in WGS84 UTM zone 19N.


