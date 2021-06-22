# Importing all libraries
library(rgdal)
library(raster)
library(caret)
library(e1071)
library(snow)
library(randomForest)

setwd("C:/FIT/2nd-Sem/Remote sensing/task_5/")

img <- brick('data/clip_sc2_corrected.tif')
names(img)<- c(paste0("B", 1:10, coll=""))

# Plot the raster in RGB color composite
par(mar=c(4,8,4,4))
plotRGB(img, r = 7, g = 3, b = 2, axes = TRUE, stretch ="lin", 
        main = "False colour composite")
jpeg('false_color.jpg',width = 1000, 
     height = 800, res=200, units = "px", quality = 100, pointsize=10)
par(mar=c(4,8,4,4))
plotRGB(img, r = 7, g = 3, b = 2, axes = TRUE, stretch ="lin", 
        main = "False colour composite")
dev.off()

trainData <- shapefile('data/signature.shp')
val <- extract(img, trainData)
responseCol <- "MC_ID"

dfAll = data.frame(matrix(vector(), nrow = 0, ncol = length(names(img))+ 1))
for (i in 1:length(unique(trainData[[responseCol]]))){
  category <- unique(trainData[[responseCol]])[i]
  categorymap <- trainData[trainData[[responseCol]] == category,]
  dataSet <- extract(img, categorymap)
  if(is(trainData, "SpatialPointsDataFrame")){
    dataSet <- cbind(dataSet, class = as.numeric(rep(category, nrow(dataSet))))
    dfAll <- rbind(dfAll, dataSet[complete.cases(dataSet),])
  }
  if(is(trainData, "SpatialPolygonsDataFrame")){
    dataSet <- dataSet[!unlist(lapply(dataSet, is.null))]
    dataSet <- lapply(dataSet, function(x){cbind(x, class = as.numeric(rep(category, nrow(x))))})
    df <- do.call("rbind", dataSet)
    dfAll <- rbind(dfAll, df)
  }
}
nsamples <- 1000
sdfAll <- dfAll[sample(1:nrow(dfAll), nsamples), ]
modFit_rf <- train(as.factor(class) ~ B1 + B2 + B3 + B4 + B5 + B6 + B7 + B8 + B9 + B10, method = "rf", data = sdfAll)
beginCluster()
preds_rf <- clusterR(img, raster::predict, args = list(model = modFit_rf))
endCluster()
plot(preds_rf)

writeRaster(preds_rf,"Classified.tif",format="GTiff", overwrite=TRUE)

nlcdclass <- c("River", "Build-ups", "Roads", "Grassland", "Trees", "Soil", "Unused farmland", "Pond with moss")
classdf <- data.frame(classvalue1 = c(1,2,3,4,5,7,8,9), classnames1 = nlcdclass)
classcolor <- c("#00BFFF", "#FF8000", "#808080", "#00FF7F", "#228B22", "#F4A460", "#EEE8AA", "#20B2AA")
library(rasterVis)
pr2011 <- ratify(preds_rf)
rat <- levels(pr2011)[[1]]
rat$legend <- classdf$classnames
levels(pr2011) <- rat
levelplot(pr2011, maxpixels = 1e6,
          col.regions = classcolor,
          scales=list(draw=TRUE),
          main = "Classification using Random forest")


plot(modFit_rf, uniform=TRUE, main="Classification Tree")
text(modFit_rf, cex = 0.8)
