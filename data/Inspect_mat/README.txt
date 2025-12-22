This README.txt file was generated on 2025-06-05 by Aaron Tabor, and updated on 2025-06-12 by Robyn Larracy.

--------------------
GENERAL INFORMATION
--------------------

1. Title of Dataset: StepUP-P150: A Dataset of High-Resolution Plantar Pressure Measurements with Varying Footwear Types and Walking Speeds for Gait Analysis and Recognition

2. Author Information
	A. Principal Investigator Contact Information
		Name: Erik Scheme
		Institution: University of New Brunswick
		Email: escheme@unb.ca

	B. Co-investigators
		Robyn Larracy (rlarracy@unb.ca)
		Angkoon Phinyomark (aphinyom@unb.ca)
		Ala Salehi (ala.salehi@unb.ca)
		Eve MacDonald (eve.macdonald@unb.ca)
		Saeed Kazemi (saeed.kazemi@unb.ca)
		Shikder Shafiul Bashar (sbashar@unb.ca)
		Aaron Tabor (aaron.tabor@unb.ca)

3. Date of data collection: 2023 - 2024

4. Geographic location of data collection: Health Technologies Lab (HTL), University of New Brunswick, Fredericton, New Brunswick, Canada

5. Funding sources that supported the collection of the data: This project was supported by the New Brunswick Innovation Foundation, the Atlantic Canada Opportunities Agency, and the Natural Sciences and Engineering Research Council of Canada (NSERC) Alliance grants program, in collaboration with project partners CyberNB, Knowledge Park, and Stepscan Technologies.

---------------------------
SHARING/ACCESS INFORMATION
---------------------------

1. Licenses/restrictions placed on the data: 

These data are available under a CC BY 4.0 license <https://creativecommons.org/licenses/by/4.0/> 

2. The dataset is described in detail here: https://doi.org/10.1038/s41597-025-05792-1

3. Recommended citation for this dataset: 

Larracy, Robyn; Phinyomark, Angkoonm; Salehi, Ala; MacDonald, Eve; Kazemi, Saeed; Shafiul Bashar, Shikder; Tabor, Aaron; and Scheme, Erik. (2025). StepUP-P150: A Dataset of High-Resolution Plantar Pressure Measurements with Varying Footwear Types and Walking Speeds for Gait Analysis and Recognition. Federated Research Data Repository. doi:https://doi.org/10.20383/103.01285.

Please also cite the complete dataset descriptor: 

Larracy, R., Phinyomark, A., Salehi, A., MacDonald, E., Kazemi, S., Bashar, S. S., Tabor, A., & Scheme, E. (2025). A dataset of high-resolution plantar pressures for gait analysis across varying footwear and walking speeds. Scientific Data 12, 1415. https://doi.org/10.1038/s41597-025-05792-1

-----------------
DATASET OVERVIEW
-----------------

The StepUP-P150 dataset includes high resolution underfoot pressures (in kPa) from 150 individuals captured using a 3.6 m by 1.2 m runway instrumented with piezoresistive sensors (Stepscan Technologies Inc., 4 sensors/cm squared, 100 Hz sampling rate). In addition to the raw recordings, the footstep pressure data are provided in preprocessed formats, with individual footsteps extracted from the recordings, normalized to a common orientation and size, and annotated with manually-verified labels such as whether the footstep originated from the left or right foot. Full details of the protocol, instrumentation, data processing, and data quality assurance steps are provided in the associated data descriptor (https://doi.org/10.1038/s41597-025-05792-1). 

Briefly, each participant completed a series of sixteen 90-second walking trials (i.e., four walking speeds x four footwear conditions) where they walked back and forth across the pressure-sensitive platform, using a non-instrumented landing for turning around. They also completed twelve 30-second balance trials (i.e., three balance tasks x four footwear conditions). The trials are named according to the following IDs:

Standing and walking conditions:
+----+-------------------------------+
| ID |          Description          |
+====+===============================+
| S1 | Balancing on Both Feet        |
+----+-------------------------------+
| S2 | Balancing on Left Foot        |
+----+-------------------------------+
| S3 | Balancing on Right Foot       |
+----+-------------------------------+
| W1 | Preferred Speed Walking       |
+----+-------------------------------+
| W2 | Slow-to-Stop Walking          |
+----+-------------------------------+
| W3 | Slower than Preferred Walking |
+----+-------------------------------+
| W4 | Faster than Preferred Walking |
+----+-------------------------------+

Footwear conditions:
+----+------------------------------------------------+
| ID |                   Description                  |
+====+================================================+
| BF | Without Footwear (Barefoot or Sockfoot)        |
+----+------------------------------------------------+
| ST | Standard Sneakers (Adidas Grand Court 2.0)     |
+----+------------------------------------------------+
| P1 | Participant's First Pair of Personal Footwear  |
+----+------------------------------------------------+
| P2 | Participant's Second Pair of Personal Footwear |
+----+------------------------------------------------+


-----------------
FOLDER STRUCTURE 
-----------------

The repository is organized using the folder structure below. For convenience, the data files are provided in both .npz (NumPy/Python compatible) and .mat (MATLAB compatible) file formats; the top level folders ‘py’ and ‘mat’ are used to organize these file types, respectively. The Python version of the dataset is approximately 50 GB in size, and the MATLAB version is approximately 118 GB in size. Within the py and mat folders, the data is arranged by participant ID (001 to 150), then by footwear condition (‘BF’, ‘ST’, ‘P1’, and ‘P2’), then by the balance or walking trial (‘S1’, ‘S2’, ‘S3’, ‘W1’, ‘W2’, ‘W3’, or ‘W4’). The top level ‘example_code’ folder has scripts for working with the data in both MATLAB and Python, including utilities for loading and plotting the recordings. Refer to the README.txt file in the example_code folder for additional details. 


├── {py,mat}
│   ├── 001
│   │   ├── BF
│   │   │   ├── S1
│   │   │   │	├── trial.{npz,mat}
│   │   │   │	└── preprocessed.{npz,mat}
│   │   │   ├── S2
│   │   │   ├── S3
│   │   │   ├── W1
│   │   │   │	├── metadata.csv
│   │   │   │	├── trial.{npz,mat}
│   │   │   │	├── pipeline_1.{npz,mat}
│   │   │   │	└── pipeline_2.{npz,mat}
│   │   │   ├── W2
│   │   │   ├── W3
│   │   │   └── W4
│   │   ├── P1
│   │   ├── P2
│   │   └── ST
│   ├── 002
│   ├── 003
│   │		.
│   │		.
│   │		.
│   └── 150
├── example_code
│   ├── matlab
│   │   ├── load_data.m
│   │   └── utils.m
│   ├── python
│   │   ├── load_data.ipynb
│   │   ├── utils.py
│   │   ├── normalize_footsteps.ipynb
│   │   ├── extract_gait_features.ipynb
│   │   └── requirements.txt
│   └── README_code.txt
├── participant_metadata.csv
└── README.txt


-----------------
FILE DESCRIPTION
-----------------

Located at the top level, the spreadsheet named ‘participant_metadata.csv’ contains demographic, anthropometric, and other participant-level information for each of the 150 individuals (see the codebook in Table 4 of the data descriptor).


For each balance trial (S1, S2, S3), the following data files are provided: 

A. trial.{npz,mat}: a 3D tensor of the full 30-second trial recording, with shape: (approx. 3000 frames x 720 px x 240 px).

B. preprocessed.{npz,mat}: a 3D tensor that has been spatially cropped to the region of interest and roughly aligned to a common coordinate space, with shape: (3000 frames x 180 px x 180 px).


For each walking trial (W1, W2, W3, W3), the following data files are provided:

A. metadata.csv: labels, 3D bounding boxes, and parameters extracted during processing for each footstep that occurred in the 90-second trial. A full description of metadata fields is provided in Table 5 of the data descriptor. 

B. trial.{npz,mat}: a 3D tensor containing the full 90-second pressure recording with shape: (approx. 9000 frames x 720 px x 240 px).

C. pipeline_1.{npz,mat}: a 4D tensor containing extracted footsteps preprocessed using pipeline #1 (see the Footstep Normalization section of the data descriptor) with shape: (number of footsteps x 101 frames x 75 px x 40 px).

D. pipeline_2.{npz,mat}: a 4D tensor containing extracted footsteps preprocessed using pipeline #2 (see the Footstep Normalization section of the data descriptor) with shape: (number of footsteps x 101 frames x 75 px x 40 px).
