library(shiny)
library(bslib)
library(dplyr)
library(plotly)
library(data.table)

#############################
## 1) Read Multiple Data   ##
##    Frames & Combine     ##
#############################

# Example raw data frames (in practice, you'd read from CSV, Excel, a database, etc.)
# Below are placeholders just as an example:

df_raw_1 <- data.frame(
  Country = c("China-US", "China-US", "UK-US", "Germany-US"),
  Year    = c(2009, 2010, 2000, 1998),
  Value   = c(0.54, 0.80, 0.12, 0.16),
  source  = "Figure1-b",
  iso3c   = c("CHN", "CHN", NA, "DEU"),
  stringsAsFactors = FALSE
)

df_raw_2 <- data.frame(
  Country = c("China-US", "UK-US", "Germany-US"),
  Year    = c(2011, 1999, 1999),
  Value   = c(0.66, 0.25, 0.19),
  source  = "Figure1-b",
  iso3c   = c("CHN", NA, "DEU"),
  stringsAsFactors = FALSE
)

df_raw_3 <- data.frame(
  Country = c("China-US", "China-US", "UK-US", "Germany-US"),
  Year    = c(2012, 2013, 1998, 1996),
  Value   = c(0.78, 0.93, 0.23, 0.14),
  source  = "Figure1-b",
  iso3c   = c("CHN", "CHN", NA, "DEU"),
  stringsAsFactors = FALSE
)

# Combine them into a single data frame
df_combined <- bind_rows(df_raw_1, df_raw_2, df_raw_3)

# Clean/tidy/format the combined data.
# Below are some example steps you might do:
df <- df_combined %>%
  # Remove duplicates if any
  distinct() %>%
  # Remove any rows that are obviously incomplete or invalid
  filter(!is.na(Country), !is.na(Year), !is.na(Value)) %>%
  # Example: If you need to adjust an iso3c, do it here. E.g. if your US iso3c is missing, fill with "USA"
  mutate(
    iso3c = ifelse(grepl("US", Country) & is.na(iso3c), "USA", iso3c)
  )

##############################################
## 2) Manual Mapping: Pair -> Two ISO Codes ##
##############################################
# This mapping ensures we can highlight both countries on the map for a chosen pair
pair_to_iso <- list(
  "China-US"   = c("CHN", "USA"),
  "UK-US"      = c("GBR", "USA"),  # "UK" iso3 is "GBR"
  "Germany-US" = c("DEU", "USA")
)

###########################
## 3) Create Shiny Theme ##
###########################
app_theme <- bs_theme(
  version = 5,
  bootswatch = "lux",
  primary = "#2c3e50",
  secondary = "#18bc9c",
  base_font = font_google("Open Sans"),
  heading_font = font_google("Raleway")
)

###########################
## 4) Shiny UI Layout    ##
###########################
ui <- page_fluid(
  theme = app_theme,
  
  tags$div(
    style = "background-color: #2c3e50; padding: 20px; border-radius: 4px; margin-bottom: 20px;",
    tags$h1("Paired Collaboration Explorer", style = "color: #fff; text-align: center; margin: 0;"),
    tags$p("Explore scientific or technological collaborations between paired countries over time.",
           style = "color: #eee; text-align: center; margin: 0;")
  ),
  
  fluidRow(
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

#####################################
## 5) Shiny Server Logic           ##
#####################################
server <- function(input, output, session) {
  
  # Debounce year selection to avoid too-frequent updates
  selected_year <- debounce(reactive(input$year), 300)
  
  # Reactive subset for the chosen pair
  pair_data <- reactive({
    df %>%
      filter(Country == input$pairSelector)
  })
  
  ##########################
  # 1) Time-Series Plot    #
  ##########################
  output$pairLinePlot <- renderPlotly({
    data_subset <- pair_data()
    
    if (nrow(data_subset) == 0) {
      return(plotly_empty(type = "scatter", mode = "lines"))
    }
    
    plot_ly(
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
        xaxis = list(title = "Year", gridcolor = "#ecf0f1"),
        yaxis = list(title = "Value", gridcolor = "#ecf0f1"),
        hovermode = "closest",
        plot_bgcolor = "#ffffff",
        legend = list(orientation = 'h', x = 0.3, y = -0.2),
        margin = list(r = 40, t = 50)
      )
  })
  
  ##########################
  # 2) World Map Plot      #
  ##########################
  output$pairMap <- renderPlotly({
    data_subset <- pair_data()
    # Filter only for the row matching the selected year
    map_row <- data_subset %>% filter(Year == selected_year())
    
    if (nrow(map_row) == 0) {
      return(plotly_empty(type = "scatter", mode = "markers"))
    }
    
    # Retrieve ISO codes for the pair
    pair <- input$pairSelector
    iso_codes <- pair_to_iso[[pair]]
    
    if (is.null(iso_codes)) {
      return(plotly_empty(type = "scatter", mode = "markers"))
    }
    
    # Build a small data frame for the countries in this pair
    map_data <- data.frame(
      iso3c = iso_codes,
      Value = rep(map_row$Value, length(iso_codes)),
      stringsAsFactors = FALSE
    )
    
    plot_geo(map_data, height = 300) %>%
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
          showframe      = FALSE,
          showcoastlines = TRUE,
          projection     = list(type = "natural earth"),
          bgcolor        = "rgba(0,0,0,0)",
          landcolor      = "#f8f9fa"
        ),
        margin = list(b = 80)
      )
  })
}

# 6) Run the application
shinyApp(ui, server)