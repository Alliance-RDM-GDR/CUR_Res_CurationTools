##### ABOUT #####
#> Open, check, and understand image files, currently extensions: .png, .jpg, .tiff
#> Started by Natalie Williams
#> Date started: July 28, 2025
#> 
#> Intent:
#> perform standardized file checking for image files. Currently runs on {.jpg, .jpeg, .png, .tiff} but could be used with other image extensions
#> Steps:
#> 1. Get file names of files with image-related extensions
#> 2. Get column names and data types from each file in list
#> 2. Get metadata
#>   a. device information
#>   b. size of image
#>   c. geography
#>   d. date/time
#> 3. Write table to file for checking against metadata 
#>
#> Assumptions:
#>   1. All zips, tars, etc have already been opened/extracted/uncompressed
#>   2. This will be run in the directory of the data deposit
#>   
#> Further work to be done:
#> 1. Unknown if custom metadata will be captured by either method of reading in metadata.
#> 2. Untested on BioImage specific file formats (e.g. OMERO tiffs)
#> 3. Untested on TIFFs; running through both magick and exif likely redundant; to choose which will work better on clusters. Or read in with magick to confirm it can be opened, and use exifr to scrape metadata?
#> 4. pull out smaller/larger images if there is size variation
#> 5. Check consistency of metadata (currently this just opens the files and reads the metadata)
#####
install.packages("exiftoolr")
install.packages("magick")
library("exiftoolr")
library("magick")
library("tidyverse")

files.jpg <- list.files(pattern = "*.jpg",recursive = TRUE,ignore.case = TRUE) #get list of all .jpg files in data set 
files.jpeg <- list.files(pattern = "*.jpeg",recursive = TRUE,ignore.case = TRUE) #get list of all .jpeg files in data set 
files.png <- list.files(pattern = "*.png",recursive = TRUE,ignore.case = TRUE) #get list of all .png files in data set 
files.tiff <- list.files(pattern = "*.tiff",recursive = TRUE,ignore.case = TRUE) #get list of all .tiff files in data set 
files.img <- bind_rows(
  as.data.frame(files.jpg),
  as.data.frame(files.jpeg),
  as.data.frame(files.png),
  as.data.frame(files.tiff)
)

#read metadata from image files using magick
img.info = data.frame()
for (i in files.img) {
  temp <- image_read(i)
  temp.info <- image_info(temp) %>%
    mutate(name = i)
  img.info <- rbind(img.info,temp.info)
}

summary(img.info)

write.csv(img.info,file = paste0("Image_Metadata_Magick_",Sys.Date(),".csv"))

#read metadata from image files using exiftool
install_exiftool()

img.info2 = data.frame()
for (i in files.img) {
  temp <- exif_read(i)
  img.info2 <- bind_rows(img.info2,temp)
}

summary(img.info2)

write.csv(img.info2,file = paste0("Image_Metadata_exifr_",Sys.Date(),".csv"))
