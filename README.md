# Curation Tools for Research Data Curators
This repository holds useful scripts, commands, and strategies for curating large amounts of data (large files or large numbers of files). Scripts may be shared or used as-is, or adapted to your own environment. These are updated and maintained pragmatically, as needs arise and capacity allows. They are optimised for using on the Alliance's ARC clusters, but many could be used locally as well.
The intent is for each script to run independently of the others, so each can be used on their own. 

## Script Descriptions
The following table describes each script with the following: Code it is written in (Language), Description of actions (Description), Output, Dependencies. 

### Preparing
| Script | Language | Description | Output | Dependencies |
|--------|----------|-------------|--------|--------------|
| Unzip.sh | Shell | Unpack any .zip files in the directory | Unpacked files | None |
| FileExtensionGen.R | R | Determine the file extension for each file by taking text to the right of the last period ("."). Files without an extension are retained with their full pathname. Tabulate the occurences of each file extension | .csv file with a count of each file extension. Files without an extension are retained with their full pathname and a count of 1. | Tidyverse R package (specifically dplyr) |
### Checking
| Script | Language | Description | Output | Dependencies |
|--------|----------|-------------|--------|--------------|
| Check_CSVs.R | R | Read in all .csv files and get: Column names, data type, number of rows / length of column, number of NAs, Minimum value, Maximum value, mean and median values (numeric data only). Then take file name, column name, and data type and make a table of column names for each file with the data types as values. This is to allow you to check consistency of naming and data structure across multiple files. | Two csv tables: MetaData_CSV.csv and ColumnCheck_CSV.csv | tidyverse R package (specifically dplyr) |
| Check_images.R | R | Read in all PNG, JPG, JPEG, and TIFF files and scrape metadata using exiftool. Also opem images and get metadata from images (to confirm they open well) with magick. | Two csv files of file name and associated metadata for each image: Image_Metadata_exifr_[YYYY-MM-DD].csv, Image_Metadata_Magick_[YYYY-MM-DD].csv | exiftoolr; magick; tidyverse |
| FFMPEGErrorCheck.sh | Shell | Run each mp4 file (can update to other video types). If an error occurs, write error to errors.log (plain text file) | Log file of errors when checking video. | FFMPEG |
| OpenFiles_gpkg.qmd | Quarto Markdown | Read in a .gpkg (GeoPackage) file, get the summary information (metadata), and plot to make sure it is working properly. | Html file with sumary information and plot | Quarto, sf R package |
