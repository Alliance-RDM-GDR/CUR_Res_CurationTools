library(tidyverse)

#get list of all files in current directory
all.files <- list.files(recursive = TRUE,full.names = FALSE,all.files = TRUE)

file.types <- as.data.frame(all.files) %>%
  mutate(file.type = gsub("[[:print:]]*\\.","",all.files)
           ) %>%
  count(file.type)
write.csv(file.types,"Pub1276_file_formats.csv")