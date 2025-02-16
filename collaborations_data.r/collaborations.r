library(shiny)
library(bslib)
library(dplyr)
library(plotly)
library(data.table)
library(tidyr)      # for unnest

#################################################
## 1) Load the data
#################################################
df_raw <- read.csv("./data/collabs_df_ds.csv", stringsAsFactors = FALSE)

# At the moment, your data has columns:
#   Country, year, value, source, iso3c
# But our Shiny code expects columns named "CollabGroup", "Year", "Value", "iso3c".
# So we rename them appropriately:
df <- df_raw %>%
  rename(CollabGroup = Country,
         Year        = year,
         Value       = value)

# Quick peek:
# print(head(df, 10))

################################################
## 2) Shiny UI Construction
################################################

app_theme <- bs_theme(
  version = 5,
  bootswatch = "lux",
  primary = "#2c3e50",
  secondary = "#18bc9c",
  base_font = font_google("Open Sans"),
  heading_font = font_google("Raleway")
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
    # Left Column: Control Panel
    column(
      width = 4,
      card(
        style = "margin-bottom: 20px;",
        card_header("Controls", class = "bg-primary text-white"),
        card_body(
          # Collaboration group selection
          selectInput(
            inputId  = "collabSelector",
            label    = "Select Collaboration Group:",
            choices  = sort(unique(df$CollabGroup)), 
            selected = sort(unique(df$CollabGroup))[1],
            multiple = FALSE,
            width    = "100%"
          ),
          
          # Year Slider
          sliderInput(
            inputId = "year", 
            label   = "Year",
            min     = min(df$Year, na.rm = TRUE),
            max     = max(df$Year, na.rm = TRUE),
            value   = min(df$Year, na.rm = TRUE),
            step    = 1,
            animate = FALSE,
            width   = "100%"
          )
        )
      )
    ),
    
    # Right Column: Visualization Panel
    column(
      width = 8,
      card(
        style = "margin-bottom: 20px;",
        full_screen = TRUE,
        card_header("Interactive Visualizations", class = "bg-primary text-white"),
        card_body(
          plotlyOutput("collabLinePlot", height = "50vh"),
          tags$hr(),
          plotlyOutput("collabMap", height = "45vh")
        )
      )
    )
  ),
  
  # Footer
  tags$footer(
    style = "
      background-color: #f8f9fa; 
      padding: 15px; 
      margin-top: 20px; 
      border-top: 1px solid #ddd;
    ",
    tags$div(
      class = "text-center",
      "Data source: multi-country collaboration dataset"
    )
  )
)

################################################
## 3) Shiny Server Logic
################################################
server <- function(input, output, session) {
  selected_year <- debounce(reactive(input$year), 300)
  
  collab_data <- reactive({
    req(input$collabSelector)
    df %>%
      filter(CollabGroup == input$collabSelector) %>%
      arrange(Year)  # Ensure chronological ordering
  })
  
  output$collabLinePlot <- renderPlotly({
    data_subset <- collab_data()
    if (nrow(data_subset) == 0) return(plotly_empty())
    
    # Aggregate values by year (in case of multiple entries)
    data_agg <- data_subset %>%
      group_by(Year) %>%
      summarise(Value = mean(Value, na.rm = TRUE))
    
    plot_ly(data_agg, x = ~Year, y = ~Value, type = "scatter", mode = "lines+markers",
            line = list(width = 2, color = "#2c3e50"),
            marker = list(size = 6, color = "#18bc9c")) %>%
      layout(title = paste("Time Series for:", input$collabSelector),
             xaxis = list(title = "Year"), 
             yaxis = list(title = "Value"))
  })
  
  output$collabMap <- renderPlotly({
    data_subset <- collab_data()
    map_subset <- data_subset %>% filter(Year == selected_year())
    if (nrow(map_subset) == 0) return(plotly_empty())
    
    # Split ISO3 codes and create mapping data
    iso_data <- map_subset %>%
      mutate(iso3c = strsplit(iso3c, "-")) %>%
      tidyr::unnest(iso3c) %>%
      distinct(iso3c, .keep_all = TRUE)
    
    # Get country names for hover text
    iso_data <- iso_data %>%
      mutate(
        Country = countrycode(iso3c, "iso3c", "country.name", 
                             custom_match = c("Unknown" = "Unknown"))
      )
    
    plot_geo(iso_data) %>%
      add_trace(
        z = ~Value, 
        locations = ~iso3c,
        color = ~Value,
        colors = "Blues",
        text = ~paste0(
          "<b>", Country, "</b><br>",
          "Collaboration Value: ", round(Value, 2), "<br>",
          "Year: ", selected_year()
        ),
        hoverinfo = "text"
      ) %>%
      layout(
        title = paste("Collaboration Countries in", selected_year()),
        geo = list(showframe = FALSE, projection = list(type = "natural earth"))
      )
  })
}

# Launch the app
shinyApp(ui, server)