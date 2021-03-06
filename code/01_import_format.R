
################################################################################
# Imports and formats GPS collar data for mountain goats on Kodiak Island      #
#                                                                              #
# Author: McCrea Cobb <mccrea.cobb@fws.gov>                                    #
# Last modified: 5/13/2019                                                     #
################################################################################


## The following functions import the ATS Globalstar and Telonics GPS collar
## data set, and reformats it for mapping and analyses.


## ---- _ImportFormat.R

#-------------------------------------------------------------------------------
## 1. Import and and format the ATS data
ImportFormat <- function() {
  message("Importing ATS collar data...")
  dfATS <-read.table("./data/raw/ats/Cumulative_D8208_20190429210216.txt", header = TRUE, sep = ",")
  SerialNum <- read.table("./data/raw/SerialNum.txt", header = TRUE, sep = ",")
  
  colnames(dfATS) <- c("SerialNum", "Year", "Day", "Hour", "Lat", "Long",
                       "Hdop", "NumSats", "FixTime", "Fix2D3D")
  dfATS$Year <- factor(paste(20, dfATS$Year, sep =""))  # Convert Year to a factor
  dfATS$SerialNum <- factor(dfATS$SerialNum)  # Convert SerialNum to a factor
  dfATS$Fix2D3D <- factor(dfATS$Fix2D3D)  # Convert 2D3D to a factor
  SerialNum$SerialNum <- factor(SerialNum$SerialNum)
  dfATS <- merge(dfATS, SerialNum, by = "SerialNum")
  
  dfATS$Date <- as.factor(format(strptime(dfATS$Day, format = "%j"),
                                 format = "%m/%d"))
  dfATS$Date <- as.factor(paste(dfATS$Date, dfATS$Year, sep = "/"))
  dfATS$Date <- strptime(paste(dfATS$Date, dfATS$Hour, sep = " "), "%m/%d/%Y %H")
  dfATS$Date <- as.POSIXct(dfATS$Date)
  dfATS$Date <- lubridate::round_date(dfATS$Date, unit="hour")
  
  dfATS <- subset(dfATS, Date >= "2015-08-01")  # subset dates after collaring
  dfATS <- unique(dfATS)  # removes any duplicate values
  
  # Clean up:
  dfATS$SerialNum <- NULL
  dfATS$FixTime <- NULL
  dfATS$NumSats <- NULL
  dfATS$Year <- NULL
  dfATS$Hour <- NULL
  dfATS$Day <- NULL
  rm(SerialNum)
  
  # Add a dummy variable for used/avail:
  dfATS$Response <- 1
  
  # Add a variable for the type of collar (Telonics/ATS)
  dfATS$Collar <- "ATS"
  
  
  #-------------------------------------------------------------------------------
  ## 2. Import and format the Telonics collar data ###
  
  message("Importing Telonics collar data...")
  
  dfTel13 <-read.table("./data/raw/telonics/Telonics2013CollarData.csv", header = TRUE, sep = ",")
  dfTel15 <-read.table("./data/raw/telonics/Telonics2015CollarData.csv", header = TRUE, sep = ",")
  
  
  
  telonics.cleanup <- function(dfTel) {
    
    require(lubridate)
    
    dfTel$Lat <- dfTel$GPS_Latitu  # Rename Lat
    dfTel$GPS_Latitu <- NULL
    
    dfTel$Long <- dfTel$GPS_Longit  # Rename Long
    dfTel$GPS_Longit <- NULL
    
    dfTel <- dfTel[dfTel$GPS_Fix_At %in% c("Succeeded (2D)", "Succeeded (3D)"), ]
    dfTel <- droplevels(dfTel)
    levels(dfTel$GPS_Fix_At) <- c("2", "3")  # Format and rename "Fix2D3D"
    dfTel$Fix2D3D <- dfTel$GPS_Fix_At
    dfTel$GPS_Fix_At <- NULL
    
    dfTel$GPS_Horizo <- NULL  # Rename pdop
    dfTel$Pdop <- dfTel$GPS_Positi
    
    dfTel$GPS_UTM_Zo <- NULL  # Clean up
    dfTel$GPS_UTM_No <- NULL
    dfTel$GPS_UTM_Ea <- NULL
    dfTel$GPS_Altitu <- NULL
    dfTel$GPS_Speed <- NULL
    dfTel$Predeploym <- NULL
    dfTel$GPS_Headin <- NULL
    dfTel$GPS_Positi <- NULL
    dfTel$GPS_Satell <- NULL
    dfTel$GPS_Sate_1 <- NULL
    dfTel$GPS_Naviga <- NULL
    dfTel$FID <- NULL
    dfTel$Activity_C <- NULL
    dfTel$Temperatur <- NULL
    dfTel$GPS_Sate_2 <- NULL
    dfTel$GPS_Sate_3 <- NULL
    dfTel$ned60m_mos <- NULL
    dfTel$Error <- NULL
    dfTel$GPS <- NULL
    dfTel$Fix <- NULL
    dfTel$DOP <- NULL
    
    # Format Dates
    
    dfTel$Date <- strptime(paste(dfTel$GPS_Fix_Da, dfTel$GPS_Fix_Ti), "%m/%d/%Y %H:%M:%S")
    dfTel$Date <- as.POSIXct(dfTel$Date)
    dfTel$Date <- lubridate::round_date(dfTel$Date, unit="hour")  # round Dates to the nearest hour
    
    dfTel$GPS_Fix_Da <- NULL
    dfTel$GPS_Fix_Ti <- NULL
    
    # Add a dummy variable for used/avail:
    dfTel$Response <- 1
    
    # Add a variable for the type of collar (Telonics/ATS)
    dfTel$Collar <- "Telonics"
    
    return(dfTel)
  }
  
  dfTel13 <- telonics.cleanup(dfTel13)
  dfTel15 <- telonics.cleanup(dfTel15)
  
  # Censor IG40, malfuncting collar that never moved from capture site
  dfTel15 <- subset(dfTel15, CollarID != "IG40")
  dfTel15 <- droplevels(dfTel15)
  
  
  #-------------------------------------------------------------------------------
  ## 3. Merge the ATS (collared in 2015) and Telonics 2015 data:
  message("Merging ATS and Telonics collar data...")
  
  df <- merge(dfATS, dfTel15, all = T)
  
  # Subset df to dates after collaring:
  df <- subset(df, Date >= "2015-08-01")
  
  # Censor erroneous fixes:
  df <- subset(df, Date != "2016-07-27 10:00:00")  # IG39 Fix
  junk <- subset(df, CollarID == "IG31" & Date == "2016-09-21 12:00:00")  # IG31 Fix
  df <- df[!row.names(df) %in% row.names(junk), ]
  
  junk <- subset(df, CollarID == "IG39" & Date == "2015-11-08 06:00:00")  # IG39 Fix
  df <- df[!row.names(df) %in% row.names(junk), ]
  
  junk <- subset(df, CollarID == "IG39" & Date == "2016-08-19 09:00:00")  # IG39 Fix
  df <- df[!row.names(df) %in% row.names(junk), ]
  
  junk <- subset(df, CollarID == "IG39" & Date > "2015-11-05 00:00:00")  # IG39 post-harvest censor
  df <- df[!row.names(df) %in% row.names(junk), ]
  
  junk <- subset(df, CollarID == "IG44" & Date > "2015-10-03 00:00:00")  # IG44 post-harvest censor
  df <- df[!row.names(df) %in% row.names(junk), ]
  
  rm(junk)  # clean up
  
  
  # Clean up some of the 2013 Telonics data
  junk <- subset(dfTel13, CollarID == "IG05" & Date > "2014-10-04 00:00:00")  # Remove fixes after it was shot
  dfTel13 <- dfTel13[!row.names(dfTel13) %in% row.names(junk), ]
  rm(junk)
  
  
  # Add in Telonics 2013 data:
  df <- merge(df, dfTel13, all = T)
  
  
  # Make Collar a factor:
  df$Collar <- as.factor(df$Collar)
  
  # Drop unused factor level in CollarID:
  df$CollarID <- droplevels(df$CollarID)
  
  # Clean up
  rm(dfTel13, dfTel15, dfATS, telonics.cleanup)
  
  
  ### Add in the corrected IG01 and IG08 data
  
  df <- subset(df, CollarID != "IG01" & CollarID != "IG08")
  
  IG08 <- read.csv("./data/raw/telonics/IG08.csv")
  
  # **** FOR 2015 DATA --- remove the time slot from the dates
  IG08$Date <- as.character(IG08$Date)
  IG08$Date <- substr(IG08$Date, 1, nchar(IG08$Date) - 4)
  
  IG08$Date <- strptime(paste(IG08$Date, IG08$Time), "%m/%d/%Y %H:%M:%S")
  IG08$Date <- as.POSIXct(IG08$Date)
  IG08$Date <- lubridate::round_date(IG08$Date, "hour") # Round to the nearest hour
  
    IG08$Time <- NULL
  
  # Add a dummy variable for used/avail:
  IG08$Response <- 1
  
  # Add a variable for the type of collar (Telonics/ATS)
  IG08$Collar <- "Telonics"
  IG08$CollarID <- "IG08"
  
  IG01 <- read.csv("./data/raw/telonics/IG01.csv")
  
  IG01$Date <- strptime(paste(IG01$Date, IG01$Time), "%m/%d/%Y %H:%M:%S")
  IG01$Date <- as.POSIXct(IG01$Date)
  IG01$Date <- lubridate::round_date(IG01$Date, "hour") # Round to the nearest hour
  IG01$Time <- NULL
  
  # Add a dummy variable for used/avail:
  IG01$Response <- 1
  
  # Add a variable for the type of collar (Telonics/ATS)
  IG01$Collar <- "Telonics"
  IG01$CollarID <- "IG01"
  
  
  IG0108 <- rbind(IG01, IG08)
  IG0108$Collar <- as.factor(IG0108$Collar)
  IG0108$CollarID <- as.factor(IG0108$CollarID)
  
  
  library(plyr)
  df <- rbind.fill(df, IG0108)
  
  rm(IG01, IG0108, IG08)
  
  # Add sex:
  collars <- read.csv("./Data/individual.csv")
  sex <- collars[, c(1,5)]
  df <- merge(df, sex, by = "CollarID")
  rm(collars, sex)
  
  
  # Define the seasons (Dec-Apr = winter, Jun-Sept = summer, May and Nov = shoulder)
  library(lubridate)
  df$season <- ifelse (month(df$Date) > 11, "winter",
                       ifelse (month(df$Date) < 5, "winter",
                               ifelse (month(df$Date) == 11, "shoulder",
                                       ifelse (month(df$Date) == 5, "shoulder",
                                               "summer"))))
  
  
  # Order by CollarID and Date
  df <- df[order(as.character(df$CollarID), as.POSIXct(df$Date)), ]
  
  
  #-------------------------------------------------------------------------------
  ## 4. Save it
  message("Saving the merged collar dataset...")
  save(df, file="./data/derived/df.Rdata", compress="gzip")
  
  
  #-------------------------------------------------------------------------------
  ## 5. Create a SpatialPointsDataFrame of the merged dataset:
  
  library(sp)
  
  message("Saving the collar data as a spatial dataframe and shapefile...")
  dfSp <- SpatialPointsDataFrame(df[ , c("Long", "Lat")], df,
                                 proj4string = CRS("+proj=longlat +datum=WGS84"))
  
  # Reproject into UTM NAD83, Zone 5N:
  dfSp <- spTransform(dfSp, CRS("+proj=utm +zone=5 +datum=NAD83"))
  
  save(dfSp, file="./data/derived/geodata/dfSp.Rdata", compress="gzip")

  
  #-------------------------------------------------------------------------------
  ## 6. Save as a shapefile
  
  rgdal::writeOGR(obj=dfSp, dsn="./data/derived/geodata/dfSp_shapefile", 
           layer="dfSp", 
           driver="ESRI Shapefile", 
           overwrite_layer = T)
  
  rm(dfSp)
  
  message("...Done")
}

