## UI ####
tableDescrMainUI <- function(){
  tagList(
    tags$h3("Descriptive table:",style = "color: steelblue;"),
    DTOutput(outputId = "Input_tableDescr")  %>% withSpinner(color="#0dc5c1"),
    tags$br(),
    tags$h3("Comparison table:",style = "color: steelblue;"),
    DTOutput(outputId ="Input_tableStat")  %>% withSpinner(color="#0dc5c1"),
    tags$h3("Select a column in the comparison table to display individual graph",style = "color: #b73338;"),
    plotlyOutput(outputId ="PlotDescr"),
    textInput("PlotTitle","Choose a title"),
    textInput("PlotYAxis","Choose a Y Axis label")
    #div(style="float:left", downloadButton('dPlot', label="Download"))
  )
} #Display on the main panel

plotOptionUI <- function(){ #Display on the side panel
  tagList(
    tags$hr(), # Horizontal line --
    radioButtons("correction", "Multiple tests correction:",
                 choices = c(BH = "BH",
                             Bonferroni = "bonferroni",
                             None = "none"),
                 selected = "BH"),

    radioButtons(inputId = "Design","Design:",
                 choices = c(Paired = "paired", Unpaired = "unpaired"), selected = "unpaired", inline = TRUE),
    radioButtons(inputId = "Graph",
                   "Graph options:",
                 choices = c(Whiskers = "whiskers", Point = "point", Bar = "bar", Violin = "violin"), selected = "whiskers" )
  )

} #Display of the plot option part on the sidebar

## Server Functions ####
MytableDescr <- function(input,used_groups,calc_table){
  tableDescr <- reactive({
    validate( need( !is.null(calc_table()), "Please, upload a properly formatted dataset or use the example." ) )

    return(funMytableDescr(used_groups(),calc_table(),input$Test))
  })

  return(tableDescr)
} #Table of stats (median,mean,sd,...)

MytableStat <- function(input,used_groups,calc_table){
  MytableStat <- reactive({
    validate( need( !is.null(calc_table()), " " ) )

    return(funMytableStat(used_groups(),calc_table(),input$Design,input$Test,input$correction))

  })


  return(MytableStat)
} #Table of p-values between groups

plotDescr <- function(input,used_groups,calc_table,colorFunction,mytableStat){
  plotDescr <- reactive({
    df2 <- calc_table()
    validate( need( !is.null(df2), "" ) )
    selected <- input$Input_tableStat_columns_selected

    validate( need( !is.null(selected), "" ) )

    dim(selected) <- length(selected)
    data <- apply(selected,1,function(x){ #We create the dataset to iterate with in the funPlotDescr function
      return(list("value"=df2[,x],"gene"=colnames(df2)[x],"pvalue"=mytableStat()[2,x]))
    })




    return(funPlotDescr(used_groups(),df2,colorFunction(),data,input$Graph,input$file1$name,input$PlotTitle,input$PlotYAxis))

  })
  return(plotDescr)
} #Plot the data

## Independant Functions ####

funMytableDescr <- function(used_Groups,calc_Table,infoTest){
  ngroup <- length(levels(as.factor(used_Groups)))

  if (infoTest == "parametric") {
    ValDesc <- matrix(nrow= ngroup*2+1, ncol= length(colnames(calc_Table) ),
                      dimnames = list(c(paste("mean-", levels(as.factor(used_Groups))),
                                        paste("sd-", levels(as.factor(used_Groups))), "Normality p-value") ,
                                      colnames(calc_Table) ) )

    for (i in 1: ngroup ) {
      subdata <- calc_Table[which(used_Groups == levels(as.factor(used_Groups))[i]),]
      #changé par ColMeans to speed up: ValDesc[i,] <- apply( subdata, 2, mean, na.rm=TRUE)
      ValDesc[i,] <- colMeans( subdata, na.rm=TRUE)
      ValDesc[i+ngroup,] <- apply( subdata, 2, sd, na.rm=TRUE)
      ValDesc[ngroup*2+1,] <- apply( calc_Table, 2, function (x) shapiro.test(x)$p )
                              }
  }
  else { #unparametric
    ValDesc <- matrix(nrow= ngroup*2, ncol= length(colnames(calc_Table) ),
                      dimnames = list(c(paste("median-", levels(as.factor(used_Groups))), paste("IQR-", levels(as.factor(used_Groups)))) ,
                                      colnames(calc_Table) ) )

    for (i in 1: ngroup ) {
      subdata <- calc_Table[which(used_Groups == levels(as.factor(used_Groups))[i]),]
      ValDesc[i,] <- apply( subdata, 2, median, na.rm=TRUE)
      ValDesc[i+ngroup,] <- apply( subdata, 2, IQR, na.rm=TRUE)  }
  }


  ValDesc2 <- format(ValDesc, digits = 4)
  return(ValDesc2)
}




funMytableStat <- function(used_Groups,calc_Table,infoDesign,infoTest,infoCorrection){

  Val <- matrix(nrow= 1, ncol= length(colnames(calc_Table) ), dimnames = list(list("p.value"), colnames(calc_Table) ) )
  #pour 2 groups:
  if (length(levels(as.factor(used_Groups))) == 2) {
    #paired/unparied:
    if (infoDesign == "paired") {P = TRUE} else {P = FALSE}
    #parametric
    if (infoTest == "parametric") {
      Val[1,] <- apply( calc_Table, 2, function (x)
        t.test( x ~ used_Groups, data = calc_Table, paired = P, var.equal = TRUE, na.omit = FALSE)$p.value )
      }
    else{
      Val[1,] <- apply( calc_Table, 2, function (x)
        wilcox.test( x ~ used_Groups, data = calc_Table, paired = P)$p.value ) }

    p.adj <- apply( Val, 1, function (x)
      p.adjust( x, method = infoCorrection, n = length(Val) ) )
    colnames(p.adj) = paste("p.adjusted ",infoCorrection,sep = "")

    Val2 <- format(rbind(Val, t(p.adj)), digits = 3)
    return(Val2)
  }

  #for more than 2 groups
  else {
    if (infoTest == "parametric") {  #parametric
      if (infoDesign == "paired") {  #paired
        Val[1,] <-  apply( calc_Table, 2,function(x)
          unlist(summary(aov(x ~ factor(used_Groups) + Error( factor(rownames(calc_Table))), data = calc_Table))[1])[9] )
        ValTukey <- matrix(nrow= 1, ncol= length(colnames(calc_Table)),
                           dimnames = list("pairwise comparisons", colnames(calc_Table) ) )
        #      ValTukey <- apply( df2, 2,function(y, f)  TukeyHSD( aov( y ~ f) )$f[,4], f = group )
      }
      else {  #unpaired

        Val[1,] <-  apply( calc_Table, 2, function(y)  anova(lm( y ~ as.factor(used_Groups)))$"Pr(>F)"[1] )
        temp <- TukeyHSD( aov( calc_Table[,1] ~ factor(used_Groups)) )$`factor(used_Groups)`
        ValTukey <- matrix(nrow= length(rownames(temp)), ncol= length(colnames(calc_Table)),
                           dimnames = list( rownames(temp), colnames(calc_Table) ) )
        ValTukey <- apply( calc_Table, 2,function(y)  TukeyHSD( aov( y ~ as.factor(used_Groups) ) )$`as.factor(used_Groups)`[,4])
      }
    }
    else { #unparametric
      if (infoDesign == "paired") {  #paired
        validate( "Sorry, Friedman test is not implemented yet" )
      }
      else {  #unpaired
        Val[1,] <-  apply( calc_Table, 2, function(y)  kruskal.test(y ~ as.factor(used_Groups))$p.value )

        temp <-  dunnTest(calc_Table[,1] ~ as.factor(used_Groups), method="bh")$res[1]

        ValTukey <- matrix(nrow= length(levels(temp$Comparison)), ncol= length(colnames(calc_Table)),
                           dimnames = list( levels(temp$Comparison), colnames(calc_Table)))
        ValTukey <- apply( calc_Table, 2, function(y)  dunnTest(y ~ as.factor(used_Groups), method="bh" )$res$P.adj )
        rownames(ValTukey) <- temp[,1]
        #Dt= dunnTest(df2[,1] ~ as.factor(group), method="bh")$res$P.adj
        #ValTukey <- apply( df2, 2, function(y)  kruskalmc(y ~ as.factor(group), p.adj="holm" ) )
      }
    }

    p.adj <- apply( Val, 1, function (x)
      p.adjust( x, method = infoCorrection, n = length(Val) ) )
    colnames(p.adj) = paste("p.adjusted ",infoCorrection,sep = "")

    Val2 <- format(rbind(Val, t(p.adj), ValTukey), digits = 3)
  }

  Val2 <- format(Val2, digits = 4, sci=FALSE)
  #print(Val2, bordered = TRUE )
  return(Val2)
}

funPlotDescr <- function(used_Groups,calc_Table,gcol, data,infoGraph,infoFilename,infoPlotTitle="",infoPlotYAxis=""){
  dim(data) <- length(data)
  group <- as.factor(used_Groups)
  rown <- rownames(calc_Table)


  plotList <- lapply(data,function(elem){
    datatoto <- data.frame(Value = elem$value, group = group, id = rown )
    ec <- max(elem$value)-min(elem$value)
    if (infoGraph == "whiskers") {
        plot <-
          ggplot(data = datatoto, aes(x = group, y =  Value, fill = group, id = id) ) +
          geom_boxplot(col="black", outlier.shape = NA) + theme_classic() +
          theme(plot.title = element_text(hjust = 0.5, color="darkred", size=14, face="bold.italic") )+
          scale_fill_manual(values = gcol) +
          geom_point()+
          theme(legend.position="none") +
          labs(title=infoPlotTitle,
               y = infoPlotYAxis, x = "Groups") +
          annotate("text",x = levels(group)[length(levels(group))], y = max(elem$value)+0.1*ec, label = elem$gene, size = 4) + #Display P-value on the graph
          annotate("text",x = levels(group)[length(levels(group))], y = max(elem$value)-ec/20+0.1*ec, label = elem$pvalue, size = 4)

    }
    else{ if (infoGraph == "point") {
        plot <-
          ggplot(data = datatoto, aes(x = group, y = Value, colour = group, id = id) ) +
          theme_classic() +
          theme(plot.title = element_text(hjust = 0.5, color="darkred", size=14, face="bold.italic") )+
          geom_point(position=position_jitterdodge(dodge.width=0), size = 2) +
          scale_color_manual(values = gcol) +
          theme(legend.position="none") +
          labs(title=infoPlotTitle,
               y = infoPlotYAxis, x = "Groups") +
          annotate("text",x = levels(group)[length(levels(group))], y = max(elem$value)+0.1*ec, label = elem$gene, size = 4) + #Display P-value on the graph
          annotate("text",x = levels(group)[length(levels(group))], y = max(elem$value)-ec/20+0.1*ec, label = elem$pvalue, size = 4)

    }
      else{ if (infoGraph == "violin") {
          plot <-
            ggplot(data = datatoto, aes(x = group, y = Value, fill = group) ) +
            geom_violin(mapping = NULL, data = NULL, stat = "ydensity", position = "dodge", draw_quantiles = NULL, trim = TRUE,
                        scale = "area", na.rm = FALSE, show.legend = NA, inherit.aes = TRUE)+
            geom_point(position=position_jitterdodge(dodge.width=0), size = 2, aes(x = group, fill = group, id = id)) +
            theme_classic() +
            theme(plot.title = element_text(hjust = 0.5, color="darkred", size=14, face="bold.italic") )+
            scale_fill_manual(values = gcol) +
            theme(legend.position="none") +
            labs(title=infoPlotTitle,
                y = infoPlotYAxis, x = "Groups") +
            annotate("text",x = levels(group)[length(levels(group))], y = max(elem$value)+0.1*ec, label = elem$gene, size = 4) + #Display P-value on the graph
            annotate("text",x = levels(group)[length(levels(group))], y = max(elem$value)-ec/20+0.1*ec, label = elem$pvalue, size = 4)
      }

        else{
            datatoto$id <- factor(datatoto$id, levels = rown)
            plot <-
              ggplot(data = datatoto, aes(x = id, y = Value, fill = group) ) +
              geom_bar(stat = "identity", width = 0.5) +
              theme_classic() +
              theme(plot.title = element_text(hjust = 0.5, color="darkred", size=14, face="bold.italic"),
                    axis.text.x=element_text(angle=90))+
              scale_fill_manual(values = gcol) +
              geom_point(position=position_jitterdodge(dodge.width=0))+
              theme(legend.position="none") +
              labs(title=infoPlotTitle,
                   y = infoPlotYAxis, x = "Samples") +
              annotate("text",x = levels(datatoto$id )[length(levels(datatoto$id ))-1], y = 1.2*max(elem$value), label = elem$gene, size = 4) + #Display P-value on the graph
              annotate("text",x = levels(datatoto$id )[length(levels(datatoto$id ))-1], y = 1.1*max(elem$value), label = elem$pvalue, size = 4)


        }
      }
    }



    gplot <-  config(layout( ggplotly(plot), dragmode = "select"), toImageButtonOptions= list(filename = paste(infoFilename, paste(infoGraph,"_Plot",sep = ""),sep="_")),
                                                                                displaylogo = FALSE,
                                                                                modeBarButtonsToRemove = c('lasso2d','sendDataToCloud','zoom2d',
                                                                                                           'resetScale2d','hoverClosestCartesian','hoverCompareCartesian'
                                                                                ))
    return(gplot)
  })


  if(length(plotList) == 1){
    res <- plotList[[1]]
  }else{
    res <- subplot(as.vector(plotList),titleY = TRUE, titleX = TRUE)
  }
  return(res)


}


## Output to UI ####


tableDescrOutput <- function(output,reacMytableStat,reacMytableDescr,reacPlotDescr,reacNameTable){


  output$Input_tableDescr <- renderDT({     datatable(reacMytableDescr(),
                                                      extensions="Buttons",
                                                      options = list(pageLength = 20, searching = FALSE, dom = 'Bt',
                                                                     buttons =  list( 'copy',
                                                                                      list(extend='csv',
                                                                                           filename = paste(reacNameTable(),"_DescrTable",sep="")),
                                                                                      list(extend='excel',
                                                                                           filename = paste(reacNameTable(),"_DescrTable",sep="")),
                                                                                      list(extend='pdf',
                                                                                           filename= paste(reacNameTable(),"_DescrTable",sep="")) ))
                                                      )

  })
  output$Input_tableStat <- renderDT({     datatable(reacMytableStat(),
                                                     selection = list(mode = 'multiple', selected = 1, target = 'column'),
                                                     extensions="Buttons",
                                                     options = list(pageLength = 20, searching = FALSE, dom = 'Bt',
                                                                    buttons =  list( 'copy',
                                                                                     list(extend='csv',
                                                                                          filename = paste(reacNameTable(),"_StatTable",sep="")),
                                                                                     list(extend='excel',
                                                                                          filename = paste(reacNameTable(),"_StatTable",sep="")),
                                                                                     list(extend='pdf',
                                                                                          filename= paste(reacNameTable(),"_StatTable",sep="")) )),

                                            )  %>%  formatStyle( which(reacMytableStat()[2,] <= 0.05),  fontWeight = 'bold')

  })
  output$PlotDescr <- renderPlotly({ reacPlotDescr()     })
}
##End
