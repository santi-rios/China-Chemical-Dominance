library(shiny)
library(bslib)
library(dplyr)
library(plotly)
library(data.table)

###########################
## Example Pair Data     ##
###########################
df <- data.frame(
  Country = c(rep("China-US", 5), rep("UK-US", 5), rep("Germany-US", 5)),
  Year    = c(2009,2010,2011,2012,2013, 1996,1997,1998,1999,2000, 1996,1997,1998,1999,2000),
  Value   = c(0.54,0.80,0.66,0.78,0.93, 0.16,0.15,0.23,0.25,0.12, 0.14,0.16,0.16,0.19,0.16),
  source  = "Figure1-b",
  iso3c   = c("CHN","CHN","CHN","CHN","CHN", NA,NA,NA,NA,NA, "DEU","DEU","DEU","DEU","DEU"),
  stringsAsFactors = FALSE
)

################################################
## Manual Mapping: Pair -> Both ISO Country Codes
################################################
pair_to_iso <- list(
  "China-US"   = c("CHN", "USA"),
  "UK-US"      = c("GBR", "USA"),  # "UK" iso3 is "GBR"
  "Germany-US" = c("DEU", "USA")
)

#############################
## Shiny UI Construction   ##
#############################

# Create a Bootstrap 5 theme using bslib:
app_theme <- bs_theme(
  version = 5,          # Use Bootstrap 5
  bootswatch = "lux",   # A clean, professional look
  primary = "#2c3e50",  # Override a couple of colors
  secondary = "#18bc9c",
  base_font = font_google("Open Sans"),  # Custom fonts (optional)
  heading_font = font_google("Raleway")
)

ui <- page_fluid(
  theme = app_theme,
  
  # A top-level container with some spacing and a custom background color
  tags$div(
    style = "background-color: #2c3e50; padding: 20px; border-radius: 4px; margin-bottom: 20px;",
    tags$h1("Paired Collaboration Explorer", style = "color: #fff; text-align: center; margin: 0;"),
    tags$p("Explore scientific or technological collaborations between paired countries over time.",
           style = "color: #eee; text-align: center; margin: 0;")
  ),
  
  # Layout using cards in a row
  fluidRow(
    # Left Column: Control Panel
    column(
      width = 4,
      card(
        style = "margin-bottom: 20px;",
        card_header("Controls", class = "bg-primary text-white"),
        card_body(
          # Pair selection
          selectInput(
            inputId  = "pairSelector",
            label    = "Select Country Pair:",
            choices  = sort(unique(df$Country)), 
            selected = "China-US",
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
          plotlyOutput("pairLinePlot", height = "50vh"),
          tags$hr(),
          plotlyOutput("pairMap", height = "45vh")
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
      "Data source: Pair-based collaboration dataset"
    )
  )
)

#############################
## Shiny Server Logic      ##
#############################

server <- function(input, output, session) {
  
  # Debounced year to avoid frantic re-rendering if the user slides quickly
  selected_year <- debounce(reactive(input$year), 300)
  
  # Filter data for the chosen pair
  pair_data <- reactive({
    df %>%
      filter(Country == input$pairSelector)
  })
  
  ##########################
  # 1) Time-Series Plot   #
  ##########################
  output$pairLinePlot <- renderPlotly({
    data_subset <- pair_data()
    
    # If no rows, return an empty placeholder
    if (nrow(data_subset) == 0) {
      return(plotly_empty(type = "scatter", mode = "lines"))
    }
    
    # Basic line+marker plotly
    fig <- plot_ly(
      data       = data_subset,
      x          = ~Year,
      y          = ~Value,
      type       = "scatter",
      mode       = "lines+markers",
      line       = list(width = 2, color = "#2c3e50"),
      marker     = list(size = 6, color = "#18bc9c"),
      hoverinfo  = "text",
      text       = ~paste0(
        "<b>", Country, "</b>",
        "<br>Year: ", Year,
        "<br>Value: ", Value
      ),
      name       = ~Country
    ) %>%
      layout(
        title = list(
          text = paste("Time Series for:", input$pairSelector),
          x = 0.05
        ),
        xaxis = list(
          title = "Year", 
          gridcolor = "#ecf0f1"
        ),
        yaxis = list(
          title = "Value", 
          gridcolor = "#ecf0f1"
        ),
        hovermode = "closest",
        plot_bgcolor = "#ffffff",
        legend = list(orientation = 'h', x = 0.3, y = -0.2),
        margin = list(r = 40, t = 50)
      )
    
    fig
  })
  
  ##########################
  # 2) World Map Plot      #
  ##########################
  output$pairMap <- renderPlotly({
    data_subset <- pair_data()
    # Keep only the row matching the selected year
    map_row <- data_subset %>% filter(Year == selected_year())
    
    # If no row at that year, show empty
    if (nrow(map_row) == 0) {
      return(plotly_empty(type = "scatter", mode = "markers"))
    }
    
    # We'll highlight both countries: the iso3 from pair_to_iso
    pair <- input$pairSelector
    iso_codes <- pair_to_iso[[pair]]
    
    if (is.null(iso_codes)) {
      # If we don't have a manual mapping, show an empty map
      return(plotly_empty(type = "scatter", mode = "markers"))
    }
    
    # We'll create a small 2-row data frame for the map
    map_data <- data.frame(
      iso3c = iso_codes,
      Value = rep(map_row$Value, length(iso_codes)),
      stringsAsFactors = FALSE
    )
    
    fig <- plot_geo(map_data, height = 300) %>%
      add_trace(
        z        = ~Value,
        color    = ~Value,
        colors   = "Blues",
        locations = ~iso3c,
        text     = ~paste0("<b>Country Pair:</b> ", pair,
                           "<br><b>Value:</b> ", round(Value, 2),
                           "<br><b>Year:</b> ", selected_year()),
        hoverinfo = "text",
        marker   = list(line = list(color = "white", width = 0.5))
      ) %>%
      colorbar(
        title       = "Value",
        orientation = 'h',
        y           = -0.1
      ) %>%
      layout(
        title = list(
          text = paste("Map for", input$pairSelector, "in", selected_year()),
          x = 0.05
        ),
        geo = list(
          showframe     = FALSE,
          showcoastlines = TRUE,
          projection    = list(type = "natural earth"),
          bgcolor       = "rgba(0,0,0,0)",
          landcolor     = "#f8f9fa"
        ),
        margin = list(b = 80)
      )
    
    fig
  })
}

# Run the application
shinyApp(ui, server)