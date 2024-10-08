


#' Viewing tables in browser
#'
#' @param x Data frame
#' @param n Display n lines
#'
#' @author Zhiming Ye
#' @return A shiny website rendered by DT
#' @export
#'

ViewDF<-function(x,n=10000){
  tryCatch({as.data.frame(x)},error=function(e){stop("Not Data frame!")})
  if(nrow(x)>n&ncol(x)>=2){
    x<-x[1:n,]
  }
  else{
    warning("Not Enough for filtering")
  }
  .DFViewer(x)
}


#' Viewing Attributes of R Objects Printed in the Terminal in browser
#'
#' This function is designed to parse the attributes of objects printed by the `str()`  function. In RStudio, the Environment pane provides a good overview of objects. However, VSCode does not offer similar support. For some complex S4 objects, providing an appropriate preview method is essential.
#' @param x Object, an S4 Object is tested. If provide other type, please consider that you should modify patterns to filtering and visualize. Or you can pass an self-defined expression to x, when set `selfExpr=F`
#' @param selfExpr In default, `capture.output(str(x,strict.width="cut"))` is used for generate the attribute of object. If disable, you can pass your self expression in x
#' @param pattern1 Pattern `"^(( ..)+)"` is used to filter ` .. .. ..` like pattern and constructing tree-like object, pass to `gregexpr()` function.
#' @param pattern2 Pattern to use to fetch object name
#' @param pattern3 Pattern to used to fetch other parts
#' @param move Numeric, to adjust where the tree is start. You can set to 1 to avoid the root.
#' @param removeBlank In S4 object, the printed result starts with blank, set to TRUE to remove it
#' @author Zhiming Ye
#' @return A shiny website
#' @export
#'
ViewObj<-function(x,selfExpr=F,pattern1=NULL,pattern2=NULL,pattern3=NULL,move=1,removeBlank=T,warning=T){
  if(warning&(!isS4(x))){
    warning("Not S4 Object! It might not be correctly rendered.")
  }
  if(is.null(pattern1)){
    pattern1<-"^(( ..)+)"
  }
  if(is.null(pattern2)){
    pattern2<-".*\\.\\.([@$#%^&*]+[^:]+):.*"
  }
  if(is.null(pattern3)){
    pattern3<-".*?:"
  }
  if(!selfExpr){
    .ViewInternal(capture.output(str(x,max.level = NA,list.len=100L,strict.width="cut")),pattern1 = pattern1,pattern2=pattern2,pattern3=pattern3,move=move,removeBlank=removeBlank)
  }
  else{
    .ViewInternal(x,pattern1 = pattern1,pattern2=pattern2,pattern3=pattern3,move=move,removeBlank=removeBlank)
  }
}
#' Viewing list in browser
#'
#' @param x A List
#'
#' @author Zhiming Ye
#' @return A shiny website
#' @export
#'
ViewList <- function(x){
  if(!is.list(x)){
    stop("Not A list!")
  }
  .ViewListInternal(x)
}

#' View Environment object in shiny
#'
#' @param envir Show which environment, default is `parent.frame()`
#'
#' @author Zhiming Ye
#' @return a shiny website
#' @export
#'
ViewEnv <- function(envir=parent.frame()){
  objects <- ls(envir = envir)
  object_types <- sapply(objects, function(x) class(get(x,envir = envir))) |> as.list()
  ViewObj(object_types,warning=F)
}

#' View Environment object and return a list
#'
#' @param envir Show which environment, default is `parent.frame()`
#'
#' @author Zhiming Ye
#' @return a list
#' @export
#'
lsEnv <- function(envir=parent.frame()){
  objects <- ls(envir = envir)
  object_types <- sapply(objects, function(x) class(get(x,envir = envir)))
  return(object_types)
}

.ViewListInternal <- function(x){


  ui <- fluidPage(
    tags$head(
      tags$style(type = "text/css", "
      #shiny-disconnected-overlay {
        background-color: inherit;
        opacity: 0;
      }
    ")
    ),
    pageWithSidebar(
      titlePanel("VSCRViewer "),

      sidebarPanel(
        shinyTree("tree"),width = 10
      ),
      mainPanel(
        div(
          style = "text-align: left;",
          tags$footer(paste0("You can using Command+F to enable search in Ace Editor"), style = "font-size: 14px; color: black;")
        ),
        aceEditor("r_code",
                  mode = "r",            # Set editor mode to R
                  theme = "textmate",    # Set editor theme
                  value = capture.output(str(x,max.level = NA,list.len=100L,strict.width="cut")),
                  readOnly=T,
                  wordWrap=T,height="800px"),width = 10
      )
    ))
  server <- shinyServer(function(input, output, session) {
    output$tree <- renderTree({
      x
    })

  })
  message("Web Viewer generated. You can use Ctrl+C to cancel shiny app.\nThe webpage is static, so it won't be lost after closing, and you can continue with your other tasks.")
  shinyApp(ui=ui,server = server)

}

.ViewInternal<-function(x,pattern1,pattern2,pattern3,move=0,removeBlank=T){
  dt<-x
  tryCatch({
    require(stringr)
    require(dplyr)
    countlist<-c()
    for(i in 1:length(dt)){
      if(removeBlank){
        str <- sub("^\\s", "", dt[i])
      }
      matches <- gregexpr(pattern1, str)
      matched_part <- regmatches(str, matches)[[1]]
      count <- length(unlist(strsplit(matched_part, " ..")))
      countlist <- c(countlist,count)
    }
    countlist<-countlist+move

    Name1list<-c()
    for(i in 1:length(dt)){
      str <- sub(pattern2, "\\1", dt[i])
      Name1list <- c(Name1list,str)
    }
    Name2list<-c()
    for(i in 1:length(dt)){
      str <- sub(pattern3, "", dt[i])
      Name2list <- c(Name2list,str)
    }
    NameFull <- paste0(Name1list,Name2list)
    renamed_strings <- ave(NameFull, NameFull, FUN = function(x) {
      if (length(x) > 1) {
        paste0(x, ".", seq_along(x) - 1)
      } else {
        x
      }
    })
    names(countlist) <- renamed_strings
    spliter <- function(x,time){
      tryCatch({split_indices <- which(x == time)
      split_indices <- c(split_indices, length(x) + 1)
      groups <- mapply(function(start, end) x[start:(end-1)],
                       split_indices[-length(split_indices)],
                       split_indices[-1],
                       SIMPLIFY = FALSE)},error = function(e) {groups <- list(x)})
      if(is.list(groups)){
        TargetMin <- time
        lapply(groups,function(x){
          NAMEkeep <- names(x)
          names(x) <- NULL
          x <- as.factor(x)
          x <- as.numeric(x)
          Intv <- TargetMin - min(x)
          x <- x + Intv
          names(x) <- NAMEkeep
          return(x)
        })
      }
    }

    test1 <- spliter(countlist,1)
    # test1 <- lapply(test1,function(x){
    #     NAMEkeep <- names(x)
    #     names(x) <- NULL
    #     x <- as.factor(x)
    #     x <- as.numeric(x)
    #     names(x) <- NAMEkeep
    #     return(x)
    # })
    # test1[[1]]
    add_one <- function(x,numL) {
      if (is.numeric(x)) {
        return(spliter(x,numL))
      } else if (is.list(x)) {
        return(lapply(x, function(x)add_one(x,numL)))
      } else {
        return(x)
      }
    }
    for(i in 2:max(countlist)){
      try({test1 <- lapply(test1, function(x)add_one(x,i))})
    }
    if(!is.list(test1)){
      stop("ERROR!")
    }

  },error=function(e){
    test1<-list()
  }
  )


  ui <- fluidPage(
    tags$head(
      tags$style(type = "text/css", "
      #shiny-disconnected-overlay {
        background-color: inherit;
        opacity: 0;
      }
    ")
    ),
    pageWithSidebar(
      titlePanel("VSCRViewer "),

      sidebarPanel(
        shinyTree("tree"),width = 10
      ),
      mainPanel(
        div(
          style = "text-align: left;",
          tags$footer(paste0("You can using Command+F to enable search in Ace Editor"), style = "font-size: 14px; color: black;")
        ),
        aceEditor("r_code",
                  mode = "r",            # Set editor mode to R
                  theme = "textmate",    # Set editor theme
                  value = dt,
                  readOnly=T,
                  wordWrap=T,height="800px"),width = 10
      )
    ))
  server <- shinyServer(function(input, output, session) {
    output$tree <- renderTree({
      test1
    })

  })
  message("Web Viewer generated. You can use Ctrl+C to cancel shiny app.\nThe webpage is static, so it won't be lost after closing, and you can continue with your other tasks.")
  shinyApp(ui=ui,server = server)

}


.DFViewer<-function(x){
  tryCatch({df<-as.data.frame(x)},error=function(e){"Not Data frame!"})

  ui <- fluidPage(
    titlePanel("VSCRViewer "),
    DTOutput("mytable")
  )
  server <- function(input, output) {
    output$mytable <- renderDT({
      datatable(df, options = list(pageLength = 50, autoWidth = TRUE))
    })
  }
  message("Web Viewer generated. Viewing DF needs continously Shiny running...")
  shinyApp(ui = ui, server = server)

}




#' An enhanced method to print character vector to the console
#' @param CharacterCollection A character vector which will be print.
#' @param Type A character. Can be "c", "tab" or "plus". c means comma, tab means print in multi-lines, and plus means to separate with "+"
#' @param return if return=F, only print in console. Set TRUE to return an object.
#'
#' @return a prited result or a vector
#' @export
#' @author Zhiming Ye
#'
#'
Print.Char<-function(CharacterCollection,Type="c",return=F){

  if(Type=="tab"){
    CHAR<-"\n"
    for(i in 1:length(CharacterCollection)){
      if(i!=length(CharacterCollection)){
        CHAR<-paste0(CHAR,CharacterCollection[i],"\n")
      }
      else{
        CHAR<-paste0(CHAR,CharacterCollection[i])
      }
    }
  }
  if(Type=="c"){
    CHAR<-"\""
    for(i in 1:length(CharacterCollection)){
      if(i!=length(CharacterCollection)){
        CHAR<-paste0(CHAR,CharacterCollection[i],"\",\"")
      }
      else{
        CHAR<-paste0(CHAR,CharacterCollection[i],"\"")
      }
    }
  }
  if(Type=="plus"){
    CHAR<-"~"
    for(i in 1:length(CharacterCollection)){
      if(i!=length(CharacterCollection)){
        CHAR<-paste0(CHAR,CharacterCollection[i],"+")
      }
      else{
        CHAR<-paste0(CHAR,CharacterCollection[i])
      }
    }
  }

  if(return){
    return(CHAR)
  }
  else{
    cat(CHAR)
  }
}


#' Previewing data table elements like rownames or colnames using Ace Editor
#'
#' Display `rownames()`, `colnames()` and `head()` result in Ace Editor. Ace Editor provides searching function and basic highlight functions. You can better view it in large tables
#' @param x A data.frame, tibble ...
#' @param n_lines display n rows
#' @param enforceALL only display first 7500 objs, if want more, set enforceALL=T
#' @author Zhiming Ye
#' @return A shiny page
#' @export
#'

PreviewDF <- function(x,n_lines=7L,enforceALL=F){
  washnames <- function(y){
    if(length(y)>7500 & !enforceALL){
      y<-c(y[1:7500],"....only display first 7500 objs, if want more, set enforceALL=T")
    }
    return(y)
  }
  colname0 <- colnames(x) |> washnames()
  rownames0 <- rownames(x) |> washnames()
  ui <- fluidPage(
    tags$head(
      tags$style(type = "text/css", "
      #shiny-disconnected-overlay {
        background-color: inherit;
        opacity: 0;
      }
    ")
    ),
    titlePanel("VSCRViewer "),
    div(
      style = "text-align: left;",
      tags$footer(paste0("You can using Command+F to enable search in Ace Editor"), style = "font-size: 14px; color: black;")
    ),
    div(
      style = "text-align: center;",
      tags$footer(paste0("Col Names: "), style = "font-size: 14px; color: black;")
    ),
    aceEditor("r_code",
              mode = "r",            # Set editor mode to R
              theme = "textmate",    # Set editor theme
              value = Print.Char(colname0,Type = "tab",return = T),
              readOnly=T,
              wordWrap=T,height="150px"),
    div(
      style = "text-align: center;",
      tags$footer(paste0("Row Names: "), style = "font-size: 14px; color: black;")
    ),
    aceEditor("r_code2",
              mode = "r",            # Set editor mode to R
              theme = "textmate",    # Set editor theme
              value = Print.Char(rownames0,Type = "tab",return = T),
              readOnly=T,
              wordWrap=T,height="150px"),
    div(
      style = "text-align: center;",
      tags$footer(paste0("Head: "), style = "font-size: 14px; color: black;")
    ),
    aceEditor("r_code3",
              mode = "r",            # Set editor mode to R
              theme = "textmate",    # Set editor theme
              value = capture.output(head(x,n = n_lines)),
              readOnly=T,
              wordWrap=T,height="150px")
  )
  server <- function(input, output) {
  }
  message("Web Viewer generated. You can use Ctrl+C to cancel shiny app.\nThe webpage is static, so it won't be lost after closing, and you can continue with your other tasks.")
  shinyApp(ui = ui, server = server)
}

#' @title Arrange Table Function - Sort and filter columns of a data frame or matrix by a specified vector
#'
#' @param Mat Target matrix or df.
#' @param FilterList Accord which to sort and filter columns
#' @param mode in Version 5.6 update, new "V2" mode is enabled. you can choose the V1 mode to change to the origin mode.
#'
#' @return a Matrix
#' @export
#' @author Zhiming Ye
#'

Arrange_Table <- function(Mat, FilterList,mode="V2") {
  warning("in Version 5.6 update, new V2 mode is enabled. you can choose the V1 mode to change to the origin mode.\n")
  if(mode=="V2"){
    FilterList<-FilterList[FilterList%in%rownames(Mat)]
  }
  Mat <-
    as.data.frame(Mat) %>% dplyr::filter(rownames(Mat) %in% FilterList)
  rn1 <- rownames(Mat)
  rn2 <- FilterList
  Mat <- Mat[rn1[match(rn2, rn1)], ]
  return(Mat)
}

#' @title Standardize
#' @description Standardize according to rows
#' @param x data
#'
#' @return Standardized matrix
#' @export
#' @author Zhiming Ye
#'

std_<-function(x){
  data<-x%>%as.matrix()
  for (i in 1:dim(data)[[1]]) {
    data[i,] <- (data[i,] - mean(data[i,], na.rm = TRUE))/sd(data[i,], na.rm = TRUE)
  }
  return(data)
}



.onAttach<-function(libname,pkgname){
  require(shiny)
  require(shinyAce)
  require(shinyjs)
  require(shinyTree)
  require(DT)
  packageStartupMessage("\n***VSCRViewer***\nView DF using ViewDF, View Object using ViewObj, View List using ViewList\n=============\nAuthor:Zhiming Ye\n")
}
# attachment::att_amend_desc()
