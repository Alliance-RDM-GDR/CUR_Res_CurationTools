##### ABOUT #####
#> Open, check, and understand netCDF files, extension .nc
#> Started by Natalie Williams
#> Date started: September 18, 2025
#> 
#> Intent:
#> perform standardized file checking for netCDF files. 
#> Steps:
#> 1. Get file names of files with .nc extensions
#> 2. Get the global attributes in the headers from each file in list
#> 2. Get metadata
#> 3. Write headers and metadata to tabular file for checking en 
#>
#> Assumptions:
#>   1. All zips, tars, etc have already been opened/extracted/uncompressed
#>   2. This will be run in the directory of the data deposit
#>   
#> Further work to be done:
#> 1. Untested on corrupted files
#####
# install.packages("tidync")
library("tidync")
library("dplyr")
library("tidyr")

files.nc <- list.files(pattern = "*\\.nc",recursive = TRUE,ignore.case = TRUE) #get list of all .nc files in data set 

#initialize data frames
nc.dim = data.frame()
nc.var = data.frame()
nc.attr = data.frame()

#read metadata from netCDF files using tidync. This might be more efficient as an apply to files.nc?
for (i in files.nc) {
  temp <- tidync(i)
  temp.dim <- temp$dimension
  temp.dim$FileName <- i
  temp.var <- temp$variable
  temp.var$FileName <- i
  temp.attr <- temp$attribute
  temp.attr$FileName <- i
  nc.dim <- rbind(nc.dim,temp.dim)
  nc.var <- rbind(nc.var,temp.var)
  nc.attr <- rbind(nc.attr,temp.attr)
}
rm(temp,temp.dim,temp.var,temp.attr,i)

#update value column from list (size 1) to character
nc.attr <-  mutate(nc.attr, value = as.character(value),.keep = "unused")

# join variable attributes to variable table
nc.var2 <- left_join(nc.var,select(nc.attr,!id),by = c("name" = "variable","FileName"),suffix = c("",".attr")) %>%
  pivot_wider(
    names_from = name.attr,
    values_from = value,
    names_repair = "unique"
  ) 

#pivot global attributes for easier comparison across files
nc.attr.global <- nc.attr %>%
  filter(variable == "NC_GLOBAL") %>%
  pivot_wider(
    id_cols = FileName,
    names_from = name,
    values_from = value
  )

#write tables to file
write.csv(nc.dim,file = paste0("netCDF_dimensions_",Sys.Date(),".csv"))
write.csv(nc.var,file = paste0("netCDF_variables_",Sys.Date(),".csv"))
write.csv(nc.var2,file = paste0("netCDF_variablesWithAttributes_",Sys.Date(),".csv"))
write.csv(nc.attr,file = paste0("netCDF_attributes_all_",Sys.Date(),".csv"))
write.csv(nc.attr.global,file = paste0("netCDF_attributes_global_",Sys.Date(),".csv"))
