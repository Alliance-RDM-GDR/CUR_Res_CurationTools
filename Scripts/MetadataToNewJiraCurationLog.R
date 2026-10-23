####### Metadata to JIRA new curation log import #########
#> To prepare a csv for initiating curation logs in JIRA in bulk
#> Process: 
#> 1. claim datasets in FRDR
#> 2. Export metadata for claimed datasets
#> 3. run script to create import csv
#> 4. import into JIRA to create curation logs
#> 
######### ###

##### Setup ####
# Load libraries
library(tidyverse) #to use tidy functionality
library(optparse) #to read in command line arguments

#define command line options
option_list <- list(
  make_option(c("-d", "--directory"),type = "character",default = "", 
              help = "base directory to work from. Should be accessible to both the read location to find the metadata file and the write location to record the jira import file."),
  make_option(c("-m","--metadata"),type = "character",default = paste0("frdr-dfdr_",Sys.Date(),".csv"),
              help = "file name including relative path for metadata export file. Defaults to frdr-dfdr_[yyyy-mm-dd].csv."),
  make_option(c("-j","--jira"),type = "character",default = paste0("jira_import_",Sys.Date(),".csv"),
              help = "file name including relative path from base directory to store JIRA import file. Defaults to jira_import_[yyyy-mm-dd].csv."),
  make_option(c("-u","--user"),type = "character",
              help = "Google workspace email of curator curating these datasets"),
  make_option(c("-b","--batch"),type = "character",default = "",
              help = "Batch number of bulk claiming action in FRDR")
)

#create the parser object
opt_parser <- OptionParser(option_list = option_list)
#Parse the arguments
opt <- parse_args(opt_parser)

#set directory

##### Read in metadata #####
meta.in <- read.csv(paste0(opt$directory,"/",opt$metadata))

## for testing purposes, select 5 random rows of meta.in
# meta.in <- slice_sample(meta.in,n = 5)

###### Update metadata for jira requirements ######
meta <- meta.in %>%
  select(
    id,starts_with("dc.title"),dc.identifier.uri,frdr.preservation.justificationchoice,frdr.embargo.current,
    globus.shared_endpoint.path
  ) %>%
  unite(col = "dc.title",starts_with("dc.title"),sep = "",na.rm = TRUE) %>%
  mutate(
    doi = str_extract(dc.identifier.uri,"10\\.[[:digit:]]{3,7}\\/[[:alnum:]-\\.]+"),
    Summary = paste0("Pub ",id," - ",dc.title," ",doi),
    parent = 1,
    issue.id = row_number(id) + 1,
    work.type = "Task",
    status = "incoming"
  ) %>%
  arrange(issue.id)

##### Initiate jira csv #####
jira <- data.frame(
  work.type = "Epic",
  Summary = paste0("FRDR curation batch",opt$batch),
  issue.id=1,
  status = "Incoming"
  ) %>%
  bind_rows(meta) 

write.csv(jira,paste0(opt$directory,"/",opt$jira),na = "",row.names = FALSE)
