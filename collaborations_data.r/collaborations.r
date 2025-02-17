library(shiny)
library(bslib)
library(data.table)
library(glue)
library(countrycode)
library(plotly)
library(DT)  # DataTable for better tables

# Load Data Efficiently
data_url <- "https://raw.githubusercontent.com/santi-rios/China-Chemical-Dominance/refs/heads/main/data/collabs_df_ds.csv"
df <- fread(data_url)  # Efficiently read CSV, omitting NAs

################################################
## 2) Shiny UI Construction
################################################
app_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly"
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
        card_header("Select a Collaboration Group and a Year", class = "bg-primary text-white"),
        card_body(
          selectInput(
            inputId  = "collabSelector",
            label    = "Select Collaboration Group:",
            choices  = sort(unique(df$CollabGroup)),
            selected = "China-United States",
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
        card_header("Collaboration Summary (Click Flag for Details)", class = "bg-primary text-white"),
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
        card_header("Interactive Visualizations", class = "bg-primary text-white"),
        card_body(
          tabsetPanel(
            tabPanel("Charts",
              plotlyOutput("collabLinePlot", height = "50vh"),
              tags$hr(),
              plotlyOutput("collabMap", height = "45vh"),
              htmlOutput("countryDetails")
            ),
            tabPanel("Data Table",
              DTOutput("collabTable")  # Improved DataTable
            )
          )
        )
      )
    )
  ),
  
  tags$footer(
    style = "background-color: #f8f9fa; padding: 15px; margin-top: 20px; border-top: 1px solid #ddd;",
    tags$div(class = "text-center", 
             "Data source: ", 
             tags$a(href = "https://chemrxiv.org/engage/chemrxiv/article-details/67920ada6dde43c908f688f6", 
                    "China's rise in the chemical space and the decline of US influence", target = "_blank")) 
  )
)

################################################
## 3) Shiny Server Logic
################################################
server <- function(input, output, session) {
  selected_year <- debounce(reactive(input$year), 300)
  
  collab_data <- reactive({
    df[CollabGroup == input$collabSelector]
  })
  
  output$summaryText <- renderUI({
    data_subset <- collab_data()
    if (nrow(data_subset) == 0) return("No data for this collaboration group.")
    
    all_iso <- unique(unlist(strsplit(data_subset$iso2c, "-")))
    country_names <- countrycode(all_iso, "iso2c", "country.name", warn = FALSE)
    
    flag_urls <- paste0('<img src="https://flagcdn.com/16x12/', tolower(all_iso), '.png" width="16">')
    
    buttons <- paste0(
      '<button type="button" class="btn btn-outline-secondary btn-sm" onclick="Shiny.setInputValue(\'selectedCountry\', \'', all_iso, '\');">',
      flag_urls, " ", country_names, "</button>"
    )
    
    HTML(glue("Collaboration '{input$collabSelector}' involves {length(all_iso)} countries. 
              Data spans from {min(data_subset$Year)} to {max(data_subset$Year)}.<br> 
              <b>Countries:</b> {paste(buttons, collapse=' ')}"))
  })
  
  output$collabTable <- renderDT({
    datatable(
      collab_data()[, .(Year, Percentage = round(Percentage, 5))],
      options = list(pageLength = 10, autoWidth = TRUE)
    )
  })
  
  output$collabMap <- renderPlotly({
    map_subset <- collab_data()[Year == selected_year()]
    map_subset <- map_subset[, .(iso2c = unlist(strsplit(iso2c, "-")))]
    
    plot_geo(map_subset) %>%
      add_trace(locations = ~iso2c, text = ~iso2c, marker = list(size = 10)) %>%
      layout(title = "Collaboration Map")
  })
  
  output$collabLinePlot <- renderPlotly({
    data_subset <- collab_data()
    if (nrow(data_subset) == 0) return(plotly_empty(type = "scatter", mode = "lines"))
    
    primary_color <- "#2c3e50"
    data_for_line <- unique(data_subset[, .(Year, Value)])
    
    plot_ly(data = data_for_line, x = ~Year, y = ~Value, type = "scatter", mode = "lines+markers",
            line = list(width = 2, color = primary_color), 
            marker = list(size = 6, color = "blue"),
            hoverinfo = "text",
            text = ~paste0("<b>", input$collabSelector, "</b><br>Year: ", Year, "<br>Value: ", Value),
            name = input$collabSelector) %>%
      layout(title = paste("Time Series for:", input$collabSelector), xaxis = list(title = "Year"), yaxis = list(title = "Value"))
  })
}

shinyApp(ui, server)