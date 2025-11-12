##### ABOUT #####
#> Open, check, and understand csv files
#> Started by Natalie Williams
#> Date started: April 4, 2025
#> 
#> Intent:
#> perform standardized file checking for .csv files. May be used for other tabular data file types, including from Excel, SAS, STATA, SPSS
#> Steps:
#> 1. Get file names of csv files
#> 2. Get column names and data types from each file ending ".csv"
#> 2. Get column-specific metadata
#>   b. number of NAs per column
#>   d. Column length
#>   e. descriptive stats (max/min/med/mean)
#> 3. Write table to file for checking against metadata 
#>
#> Assumptions:
#>   1. All zips, tars, etc have already been opened/extracted/uncompressed
#>   2. File extension script FileExtensionGen.R has already been run
#>   3. This will be run in the directory of the data deposit
#>   
#> Not included:
#>  1. empty rows
#>  2. mixed file types, though checking for these can be reduced to checking the columns with character data types.
#####

library(tidyverse)

#### 1. Get file names of CSV files ####
if(exists("all.files")){
  csv.files <- grep("csv",all.files,ignore.case = TRUE,value = TRUE) #get list of all .csv files in data set
} else {
  csv.files <- list.files(pattern = "*.csv",recursive = TRUE) #get list of all .csv files in data set
  
}

#### 2. Tabulate metadata ####
#initialize data frame for iterative reading in and metadata scraping
csv.summ <- as.data.frame(c(),col.names = c("file.name","column.name","column.type","rows","min","mean","med","max","NAs")) 

#Get metadata for each file in csv.files list and add it to csv.summ
for (i in csv.files) {
  tmp <- read.csv(i) #read in the file
  #the following can likely be easier with append...
  #make table with 1 row/column in the file; file = filename with directory path; colnames = column names in the file; coltypes = auto-detected data types in each column (integer, numeric, character, date, logical, etc), rows = number of rows in table 
  tmp.meta <- data.frame(file.name = i,column.name = colnames(tmp),column.type = sapply(tmp, class),rows = nrow(tmp)) 
  #get summary statistics for each column in the file: min = minimum (all data types), mean = mean (numeric/integer only), med = median (numeric/integer only), max=maximum value (all data types), NAs = number of empty or NA values (all data types)
  tmp.stat <- tmp %>%
    summarise(
      #file = i,
      across(everything(),
             #.fns = c(NAs = ~sum(is.na(.x))),.names = "{.col}|{.fn}"),
             #across(where(~is.numeric(.x)),
             .fns = c(min = ~min(.x,na.rm = T), mean = ~mean(.x,na.rm = T),med = ~median(.x,na.rm = T),max = ~max(.x,na.rm = T),NAs = ~sum(is.na(.x))),
             .names = "{.col}|{.fn}"
      )
    ) %>%
      #make all values a character - this is so all of the values can be added as a table and meaning is preserved (numbers can be stored as strings). This is important because the summarize function prints a 1-row table, and we need to pivot it so each stat is in 1 column, and each variable from the file has its own row
    mutate(
      across(everything(),~as.character(.x)) 
    ) %>%
    #convert 1x5n table to nx6 table (5 stats + variable name) 
    pivot_longer(
      cols = everything(), #use all the columns
      names_pattern = "(.*)\\|(.*)", #tells R how to decode the column names in the summary table. A "(.)" denotes a column name
      names_to = c("column.name",".value") #the list of column names, to be used in order as specified in the pattern in the above line. ".value" means use what this is (i.e. in height|min, "height" will go into colnames, and a new column named min will be started. The value in the appropriate cell will be put into the heightXmin cell)
    )
  tmp.meta <- full_join(tmp.meta,tmp.stat,by = "column.name") #join the two temporary tables together by variable name (column colnames)
  csv.summ <- bind_rows(csv.summ,tmp.meta) #append the new table to the existing table
  
}
rm (tmp, tmp.stat,tmp.meta)

#Create a second table with 1 row / file, column names across the top and column type (numeric/character/etc) as the data value
col.compare <- csv.summ %>%
  pivot_wider(
    id_cols = c("file.name"),
    names_from = "column.name",
    values_from = "column.type"
  )
csv.summ %>%
  count(file)
#### 3. Write to file ####
write.csv(csv.summ,file = "MetaData_CSV.csv")
write.csv(col.compare,file = "ColumnCheck_CSV.csv")