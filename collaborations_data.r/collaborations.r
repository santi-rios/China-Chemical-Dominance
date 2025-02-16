####
# please reduce the dependencies and libraries if possible to make the app more efficient
###

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(plotly)
library(data.table)
library(glue)
library(countrycode)

#################################################
## 1) Load and Preprocess Data
#################################################
data_url <- "https://raw.githubusercontent.com/santi-rios/China-Chemical-Dominance/refs/heads/main/data/collabs_df_ds.csv" # nolint
df <- fread(data_url, drop = 1) # drop the first column = rownames

################################################
## 2) Shiny UI Construction
################################################
app_theme <- bs_theme(
  version = 5,
  bootswatch = "spacelab"
)

ui <- page_fluid(
  theme = app_theme,
  
  tags$div(
    style = "background-color: #2c3e50; padding: 20px; border-radius: 4px; margin-bottom: 20px;",
    tags$h1("Collaboration Explorer", style = "color: #fff; text-align: center; margin: 0;"),
    tags$p("Explore multi-country collaborations over time.",
           style = "color: #eee; text-align: center; margin: 0;")
  ),
  
  fluidRow(
    column(
      width = 4,
      card(
        style = "margin-bottom: 20px;",
        card_header("Select a Collaboration Group and a Year: ", class = "bg-primary text-white"),
        card_body(
          selectInput(
            inputId  = "collabSelector",
            label    = "Select Collaboration Group:",
            choices  = sort(unique(df$CollabGroup)),
            selected = "China-United States",
            # select a random collaboration group as default
            # selected = sample(unique(df$CollabGroup), 1),
            multiple = FALSE,
            width    = "100%"
          ),
          sliderInput(
            inputId = "year", 
            label   = "Year",
            min     = min(df$Year, na.rm = TRUE),
            max     = max(df$Year, na.rm = TRUE),
            value   = max(df$Year, na.rm = TRUE) - 1,
            step    = 1,
            ticks = FALSE,
            animate = FALSE,
            width   = "100%"
          )
        )
      ),
      
      card(
        style = "margin-bottom: 20px;",
        card_header("Collaboration Summary. Click on a country flag for more details bellow the Map.", class = "bg-primary text-white"),
        card_body(
          htmlOutput("summaryText"),
          uiOutput("flagButtons")
        )
      )
    ),
    
    column(
      width = 8,
      card(
        style = "margin-bottom: 20px;",
        full_screen = TRUE,
        card_header("Interactive Visualizations. Select a valid year in the input in order to see more information in the map plot. Click on the Data Table Tab to see more info.", class = "bg-primary text-white"),
        card_body(
          tabsetPanel(
            tabPanel("Charts",
              plotlyOutput("collabLinePlot", height = "50vh"),
              tags$hr(),
              plotlyOutput("collabMap", height = "45vh"),
              htmlOutput("countryDetails")
            ),
            tabPanel("Data Table",
              tableOutput("collabTable")
            )
          )
        )
      )
    )
  ),
  
  tags$footer(
    style = "background-color: #f8f9fa; padding: 15px; margin-top: 20px; border-top: 1px solid #ddd;",
    tags$div(class = "text-center", "Data source: China's rise in the chemical space and the decline of US influence", 
             tags$br(), "https://chemrxiv.org/engage/chemrxiv/article-details/67920ada6dde43c908f688f6"))
)

################################################
## 3) Shiny Server Logic
################################################
server <- function(input, output, session) {
  selected_year <- debounce(reactive(input$year), 300)
  
  collab_data <- reactive({
    req(input$collabSelector)
    df %>%
      filter(CollabGroup == input$collabSelector)
  })
  
  output$summaryText <- renderUI({
    data_subset <- collab_data()
    if (nrow(data_subset) == 0) return("No data for this collaboration group.")
    
    all_iso <- unique(unlist(strsplit(paste(data_subset$iso2c, collapse = "-"), "-")))
    country_names <- countrycode(all_iso, "iso2c", "country.name", warn = FALSE)
    
    flag_urls <- paste0('<img src="https://flagcdn.com/16x12/', tolower(all_iso), '.png" width="16">')
    
    buttons <- paste0(
      '<button id="btn_', all_iso, '" type="button" class="btn btn-outline-secondary btn-sm" 
      onclick="Shiny.setInputValue(\'selectedCountry\', \'', all_iso, '\', {priority: \'event\'});">',
      flag_urls, " ", country_names, "</button>"
    )
    
    HTML(glue("<b>Collaboration:</b> {input$collabSelector} <br><b>Countries:</b> <br>{paste(buttons, collapse=' ')}"))
  })
  
  output$countryDetails <- renderUI({
    req(input$selectedCountry)
    data_subset <- df %>%
      filter(grepl(input$selectedCountry, iso2c)) %>%
      summarise(
        Years = paste(unique(Year), collapse = ", "),
        AvgValue = mean(Value), 
        AvgPercentage = mean(Percentage)
      )
    
    HTML(glue("<b>Country:</b> {input$selectedCountry} <br>
              <b>Appears in Years:</b> {data_subset$Years} <br>
              <b>Average Collaboration Value:</b> {round(data_subset$AvgValue, 2)} <br>
              <b>Average Percentage:</b> {round(data_subset$AvgPercentage, 3)}%"))
  })
  
  output$collabTable <- renderTable({
    collab_data() %>%
      distinct(Year, Percentage) %>%
      arrange(Year) %>%
      mutate(Percentage = paste0(round(Percentage, 5), " %"))
  })
  
  output$collabMap <- renderPlotly({
    map_subset <- collab_data() %>%
      filter(Year == selected_year()) %>%
      separate_rows(iso2c, sep = "-")
    
    plot_geo(map_subset) %>%
      add_trace(locations = ~iso3c, z = ~Value, colors = "Blues", text = ~iso2c) %>%
      layout(title = "Collaboration Map")
  })
  
  output$collabLinePlot <- renderPlotly({
    data_subset <- collab_data()
    
    if (nrow(data_subset) == 0) {
      return(plotly_empty(type = "scatter", mode = "lines"))
    }
    
    data_for_line <- data_subset %>%
      distinct(Year, Value)
    
    fig <- plot_ly(
      data       = data_for_line,
      x          = ~Year,
      y          = ~Value,
      type       = "scatter",
      mode       = "lines+markers",
      line       = list(width = 2, color = "#2c3e50"),
      marker     = list(size = 6, color = "#18bc9c"),
      hoverinfo  = "text",
      text       = ~paste0(
        "<b>", input$collabSelector, "</b>",
        "<br>Year: ", Year,
        "<br>Value: ", Value
      ),
      name       = input$collabSelector
    ) %>%
      layout(
        title = list(text = paste("Time Series for:", input$collabSelector), x = 0.05),
        xaxis = list(title = "Year", gridcolor = "#ecf0f1"),
        yaxis = list(title = "Value", gridcolor = "#ecf0f1"),
        hovermode = "closest",
        plot_bgcolor = "#ffffff",
        legend = list(orientation = 'h', x = 0.3, y = -0.2),
        margin = list(r = 40, t = 50)
      )
    fig
  })
}

shinyApp(ui, server)