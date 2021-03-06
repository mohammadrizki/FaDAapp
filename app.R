##library########
library(shiny)            #For shiny
library(shinythemes)      #For graphics of shiny interface
library(shinycssloaders)  #For the spinner of load during the computing of the functions
library(shinyBS)          #For tooltips, popovers and alerts
library(ggplot2)          #Plot graphs
library(plotly)           #Plot interactives graphs
library(gridExtra)        #Grid display
library(grid)             #Grid display
library(gplots)           #For colorpanels in the heatmap
library(ComplexHeatmap)  #For  heatmaps
library(circlize)        #For  heatmaps
library(heatmaply)        #For interactive heatmaps
library(corrplot)        #For the correlogram


if (!requireNamespace("BiocManager", quietly = TRUE)){
  install.packages("BiocManager")
  if(!require("impute"))
    BiocManager::install("impute")
}
library(impute)           #For knn on the heatmap when there is NA values

library(FSA)              #For some tests (DunnTest)
library(DT)               #For datatabkes functions
library(shinyWidgets)     #For some shiny functions
library(RColorBrewer)     #For the color palette
library(pROC)             #For ROCCurves
if (!require("devtools"))
  install.packages("devtools")
if (!require("svglite"))
  devtools::install_github("r-lib/svglite")
library(svglite)          #For svg images
library(parallel)

## Sources ####
source("./app/general/general.R")
source("./app/tabs/about/about.R")
source("./app/tabs/about/insructions.R")
source("./app/tabs/tableDescr/tableDescr.R")
source("./app/tabs/batchPlot/batchPlot.R")
source("./app/tabs/heatmapPca/heatmapPca.R")
source("./app/tabs/correlation/correlation.R")
source("./app/tabs/ROCCurves/ROCCurves.R")
#####

# Define UI for application that draws a histogram
ui <- fluidPage(theme = shinytheme("united"),
                #titlePanel ####
                titlePanel(" ",windowTitle = "FaDA"),
                tags$head(
                  tags$style(
                    HTML("@import url('//fonts.googleapis.com/css?family=Righteous|');"),
                    HTML(".shiny-output-error-validation {
                                        color: red;
                          }")
                  )
                ),

                headerPanel(
                  div(img(src= "IconOct19.png", class = "pull-left"),
                      div(img(src= "logo.png", class = "pull-right")) )   ),

           #sidebarPanel ####
                sidebarPanel( width = 4,# Input: Select a file
                              conditionalPanel(
                                condition="input.TestTable | input.tabs != 'about' & input.tabs != 'Tutorial'",
                                               generalTableHead() ),
                                                readTableUI(), #Defined in the general.R
                              conditionalPanel(condition = "input.tabs != 'about' & input.tabs != 'Tutorial'  ",
                                          generalDataOptionUI() ),
                              conditionalPanel(condition = "input.tabs == 'Tutorial'",
                                               TutorialOptionUI() ),
                              conditionalPanel(condition =
                                                 "input.tabs == 'tableDescr' | input.tabs == 'correlation'",
                                               generalParametricOptionUI()),
                              conditionalPanel(condition = "input.tabs == 'tableDescr' ",
                                          plotOptionUI() ), #Defined in the tableDescr.R
                              conditionalPanel(condition = "input.tabs == 'correlation'",
                                          corrSidebarUI() ),
                              conditionalPanel(condition = "input.tabs == 'Heatmap_PCA' ",
                                               HeatmapOptionUI() )
                              ),

                #mainPanel ####
                mainPanel(
                  tabsetPanel(type = "pills",id = 'tabs',
                              ### The following functions are defined in the corresponding R file
                                  tabPanel("About", icon = icon("eye"), value = 'about',
                                                  #tags$style(".well {background-color:red;}"),
                                                  aboutUI()#Defined in the about.R
                                               ),
                              #Tutorial###
                              tabPanel("Tutorial",icon = icon("chart-line"), value = 'Tutorial',
                                       introductionUI()),

                              #Table 2 panels###
                             tabPanel("Data Analysis", icon = icon("table"), value = 'tableDescr',
                                      tags$br(),
                                       tabsetPanel(type = "pills", id = 'Table2panels',
                                                   tabPanel("Analysis", value = "Analysis",
                                                            tableDescrMainUI()), #Defined in the tableDescr.R
                                                   tabPanel("Grouped plots", icon = icon("signal"),
                                                            value = "batchPlot",
                                                            batchPlotUI() ) #Defined in the tableDescr.R
                                       )  ),
                              #Heatmap & PCA###
                             tabPanel("Heatmap & PCA", icon = icon("signal"), value = "Heatmap_PCA",
                                      tags$br(),
                              tabsetPanel(type = "pills", id = 'Heatmap_PCA', selected = "FixedHeatmap",
                                          tabPanel(title= "Heatmap & PCA",  value = "FixedHeatmap",
                                                   FixedHeatmap_UI(), tags$br(), FixedPCA_UI() ), #Defined in the heatmapPca.R
                                          tabPanel(title= "Interactive visualisations",  value = "iHeatmap",                                                                    heatmapPcaUI(),tags$br(),PCA_UI()
                                                   ) #Defined in the heatmapPca.R
                                      )),
                              #Correlation###
                                      tabPanel("Correlation", icon = icon("chart-line"), value = 'correlation',
                                               tags$br(),
                                        tabsetPanel(type = "pills",id = 'corrTabs',
                                                  tabPanel("Correlogram", value = "correlation_correlogram",
                                                              correlogramUI()), #Defined in the correlation.R
                                                  tabPanel("Correlation Graphs", value = "correlation_corrGraph",
                                                                    corrGraphUI())
                                                          )
                                               ),

                              #ROC###
                                      tabPanel("ROC curves", icon = icon("chart-line"), value = 'rocCurves',
                                                  ROCCurvesUI() #Defined in the ROCCurves.R
                                               )  )
                          )
                )

#####

######
# Define server
server <- function(input, output, session) {
  options(shiny.maxRequestSize=5*1024^2) #Limite de taille de fichier possible que l'utilisateur peut envoyer (ici 30 MB)
  ## Call Server Functions ####

# General
  reacUsedTable <- usedTable(input,session)
  reacUsedGroups <- usedGroups(input,reacUsedTable)
  reacCalcTable <- calcTable(input,reacUsedTable)
  reacColorFunction <- colorFunction(input,reacUsedTable)
  reacNameTable <- nameTable(input)
  observeGeneral(input,session,reacUsedTable)
# About
  Text1 <- about()
  observeUploadFileToChangeTabs(input,session)
  Textintro <- introduction()

# Description Table : summary and p-value (Tab 1)
  reacMytableDescr <- MytableDescr(input,reacUsedGroups,reacCalcTable)
  reacMytableStat <- MytableStat(input,reacUsedGroups,reacCalcTable)
  reacPlotDescr <- plotDescr(input,reacUsedGroups,reacCalcTable,reacColorFunction,reacMytableStat)
# Batch Plots (Tab 2)
  reacBatchPlot <- batchPlot(input,reacUsedGroups,reacCalcTable,reacColorFunction)
  reacMoreBatchPlot <- MoreBatchPlot(input,reacUsedGroups,reacCalcTable,reacColorFunction)

# Heatmap and PCA (Tab 3)
  reacFixedHeatmap <- FixedHeatmap(input,reacUsedGroups,reacCalcTable,reacColorFunction)
  reacHeatmap <- heatMap(input,reacUsedGroups,reacCalcTable,reacColorFunction)
  reacACP <- ACP(input,reacUsedGroups,reacCalcTable,reacColorFunction)
  reacFixedPCA <- FixedPCA(input,reacUsedGroups,reacCalcTable,reacColorFunction)

# Correlation Table (Tab 4)
  reacCorrelogram <- correlogram(input,reacCalcTable)
  reacCorrTable <- corrTable(input,reacCalcTable)
  reacPvalCorrTable <- pvalCorrTable(input,reacCalcTable)
  reacCorrGraph <- corrGraph(input,reacCalcTable)

# ROC Curve (Tab 5)
  reacROCPlot <- ROCPlot(input,reacUsedTable,reacColorFunction)
  reacAUCTable <- AUCTable(input,reacUsedTable)

  ## Output ####
# General
  generalOutput(input,output,reacUsedTable,reacNameTable)
# About
  aboutOutput(output,Text1)
  introductionOutput(output, Textintro)
# Page 1
  tableDescrOutput(output,reacMytableStat,reacMytableDescr,reacPlotDescr,reacNameTable)
  batchPlotOutput(output,reacBatchPlot)
  # Page 3
  heatmapOutput(output,reacHeatmap,reacACP,reacFixedHeatmap,reacFixedPCA)
# Page 4
  correlogramOutput(output,reacCorrTable,reacPvalCorrTable,reacCorrelogram,reacNameTable)
  corrGraphOutput(output,reacCalcTable,reacCorrGraph,reacNameTable,reacCorrTable)
# Page 5
  ROCCurvesOutput(output,reacCalcTable,reacROCPlot,reacAUCTable,reacUsedGroups,reacNameTable)

## Download Graphs ####
  extableDownload(output,session)
  FixedheatmapDownload(input,output,reacFixedHeatmap)
  FixedPCADownload(input,output,reacFixedPCA)
  batchPlotDownload(input,output, reacUsedTable, reacBatchPlot, reacMoreBatchPlot)
  corrDownload(input,output,reacCorrelogram)
  ROCDownload(input,output,reacROCPlot)

  }
###
# Run the application
shinyApp(ui = ui, server = server)

####End
