library(tidyverse)

#get list of all files in current directory
all.files <- list.files(recursive = TRUE,full.names = FALSE,all.files = TRUE)

# create data frame from list with list column named 'all.files'. Add new column 'file.type' which finds the last period (.) and removed it and everything to the left. If no (.) exists in the file name, the original is retained. Then count the number of times each file extension appears in file.type
file.types <- as.data.frame(all.files) %>%
  mutate(file.type = gsub("[[:print:]]*\\.","",all.files)
           ) %>%
  count(file.type)

#write to file. Consider updating this script to be a function that you can call, with the option to write to file as a parameter with file name an additional parameter.
write.csv(file.types,"FileExtensionTable.csv")
