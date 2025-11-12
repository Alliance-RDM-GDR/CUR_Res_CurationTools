# Curation Tools for Research Data Curators
This repository holds useful scripts, commands, and strategies for curating large amounts of data (large files or large numbers of files). Scripts may be shared or used as-is, or adapted to your own environment. These are updated and maintained pragmatically, as needs arise and capacity allows. They are optimised for using on the Alliance's ARC clusters, but many could be used locally as well.
The intent is for each script to run independently of the others, so each can be used on their own. 

## Script Descriptions
The following table describes each script with the following: Code it is written in (Language), Applicable file types, Description of actions (Description), Output, Dependencies. 

### Preparing
| Script | Language | File Type | Description | Output | Dependencies |
|--------|----------|-----------|-------------|--------|--------------|
| Unzip.sh | Shell | Zip | Unpack any .zip files in the directory | Unpacked files | None |
| unzipbz2.sh | Shell | BZ2 | Unpack any .bz2 files in multiple subdirectories | Unpacked files | None |
| FileExtensionGen.R | R | all | Determine the file extension for each file by taking text to the right of the last period ("."). Files without an extension are retained with their full pathname. Tabulate the occurences of each file extension | .csv file with a count of each file extension. Files without an extension are retained with their full pathname and a count of 1. | Tidyverse R package (specifically dplyr) |
### Checking
| Script | Language | File Type | Description | Output | Dependencies |
|--------|----------|-----------|-------------|--------|--------------|
| Check_CSVs.R | R | Tabular (csv) | Read in all .csv files and get: Column names, data type, number of rows / length of column, number of NAs, Minimum value, Maximum value, mean and median values (numeric data only). Then take file name, column name, and data type and make a table of column names for each file with the data types as values. This is to allow you to check consistency of naming and data structure across multiple files. | Two csv tables: MetaData_CSV.csv and ColumnCheck_CSV.csv | tidyverse R package (specifically dplyr) |
| Check_images.R | R | Image (PNG, JPG, JPEG, TIFF) | Read in all PNG, JPG, JPEG, and TIFF files and scrape metadata using exiftool. Also open images and get metadata from images (to confirm they open well) with magick. | Two csv files of file name and associated metadata for each image: Image_Metadata_exifr_[YYYY-MM-DD].csv, Image_Metadata_Magick_[YYYY-MM-DD].csv | exiftoolr; magick; tidyverse |
| Check_netCDF.R | R | netCDF (nc) | Read in all .nc files and get metadata (global attributes, dimensions, variables and their attributes). | Four .csv files: netCDF_dimensions_[YYYY-MM-DD].csv, netCDF_variables_[YYYY-MM-DD].csv, netCDF_attributes_all_[YYYY-MM-DD].csv, netCDF_attributes_global_[YYYY-MM-DD].csv | dyplyr, tidync R packages |
| FFMPEGErrorCheck.sh | Shell | Video (mp4) | Run each mp4 file (can update to other video types). If an error occurs, write error to errors.log (plain text file) | Log file of errors when checking video. | FFMPEG |
| OpenFiles_gpkg.qmd | Quarto Markdown | Geographic Information (GKPG) | Read in a .gpkg (GeoPackage) file, get the summary information (metadata), and plot to make sure it is working properly. | Html file with sumary information and plot | Quarto, sf R package |

**Note**: The most of the checking files can be updated to accomodate other file formats of the appropriate type. e.g. The Check_CSVs.R script can be updated to read in other tabular data, given the appropriate updates to the file extension (look for other tabular data) and the readin line (e.g. read_excel or read_sas). This may change the dependencies, but the process is very similar.
