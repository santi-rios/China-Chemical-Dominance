# libraries -----
library(stringr)
library(dplyr)
library(data.table)
library(countrycode)
library(stringr)

# functions -----

## Function to check if a country name is a two-letter code -----

is_iso2 <- function(x) {
  x %in% countrycode::codelist$iso2c
}

# Data Preparation -------

## Updated data URL ------

data_url <- "https://raw.githubusercontent.com/santi-rios/China-Chemical-Dominance/refs/heads/main/data/fig_1_complete.csv"

## Load and preprocess data -------

df <- fread(data_url) 

# Define a named vector for country name replacements (abbreviation → full name)
country_replacement <- c(
  "\\bNAM\\b" = "NA",
  "\\China\\b" = "CN"
  # "\\bUK\\b" = "United Kingdom",
  # "\\bCN\\b" = "China"
)

# Clean the Country column using regex to match whole words

data_clean <- df %>%
  mutate(Country = str_replace_all(Country, country_replacement))


df_fig1 <- data_clean %>%
  filter(source %in% c("Figure-12-a_b", "Figure1-d", "Figure1-e")) %>%
  mutate(Country = as.factor(Country), source = as.factor(source)) %>%
  mutate(Country = ifelse(is_iso2(Country),
                          countrycode(Country, "iso2c", "country.name"),
                          Country)) %>%
  na.omit()

# mutate(iso3c = countrycode(Variable, origin = "country.name", destination = "iso3c"))

str(df_fig1)
tail(df_fig1)
sort(unique(df_fig1$Country))


#########
data_url <- "https://raw.githubusercontent.com/santi-rios/China-Chemical-Rise/refs/heads/main/data/merged_figure2.csv"

chemichal_df <- fread(data_url) 

unique(chemichal_df$source)

chemichal_countries <- chemichal_df %>%
  filter(!source %in% c("Figure2-a", "Figure2-c", "Figure2-e")) %>%
  mutate(
    substance = case_when(
      source == "Figure2-b" ~ "Organometallics",
      source == "Figure2-d" ~ "Rare-earths"
    )
  )


str(chemichal_countries)
unique(chemichal_countries$Country)

# Define a named vector for country name replacements (abbreviation → full name)
country_replacement <- c(
  "\\bUS\\b" = "United States",
  "\\bUK\\b" = "United Kingdom"
  # "\\bCN\\b" = "China"
)

# Clean the Country column using regex to match whole words

chemichal_countries_clean <- chemichal_countries %>%
  mutate(Country = str_replace_all(Country, country_replacement))

str(chemichal_countries_clean)
unique(chemichal_countries_clean$Country)

# Save the cleaned dataset
# write.csv(df, "./data/fig_1_df.csv", row.names = FALSE)

############

# Merge the two datasets

df_merged <- df_fig1 %>%
  left_join(chemichal_countries_clean, by = c("Country", "Year", "iso3c"))
  # mutate(substance = ifelse(is.na(substance), "Chemicals", substance)) %>%
  # select(Country, source, substance, Value) %>%
  # rename(Variable = source)

str(df_merged)
unique(df_merged$Country)

# Save the merged dataset
write.csv(df_merged, "./data/fig_1_df.csv", row.names = FALSE)

# End of the script
df_merged %>% 
  filter(source.x == "Figure1-d") %>%
  select(Country) %>%
  unique() 

df_china <- tibble::tibble(
  Country = rep("China", 28),
  Year = 1996:2023,
  Value.x = c(8.78, 8.12, 6.82, 6.73, 7.64, 7.55, 8.4, 9.35, 9.46, 10.74, 
              12.09, 13.64, 9.09, 8.86, 10.1, 8.95, 7.13, 7.05, 6.75, 6.42, 
              6.24, 6.3, 6.25, 5.58, 2, 8.35, 3, 5.31),
  source.x = rep("Figure1-d", 28),
  iso3c = rep("CN", 28),
  Value.y = rep(NA, 28),
  source.y = rep(NA, 28),
  substance = rep(NA, 28)
)

df_merged <- rbind(df_merged, df_china)

write.csv(df_merged, "./data/fig_1_df.csv", row.names = FALSE)


df_raw <- read.csv("./data/collabs_df_ds.csv", stringsAsFactors = FALSE)

df <- df_raw %>%
  rename(CollabGroup = Country, Year = year, Value = value) %>%
  mutate(iso2c = countrycode(iso3c, "iso3c", "iso2c", warn = FALSE))  # Convert to ISO2 codes

write.csv(df, "./data/collabs_df_ds.csv", row.names = FALSE)

# Compute total collaboration values per year and country
total_per_year <- df %>%
  group_by(Year) %>%
  summarise(TotalValue = sum(Value, na.rm = TRUE)) %>%
  ungroup()

# Merge total values and calculate percentage
df <- df %>%
  left_join(total_per_year, by = "Year") %>%
  mutate(Percentage = (Value / TotalValue) * 100)

write.csv(df, "./data/collabs_df_ds.csv", row.names = FALSE)

################

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
df_raw <- read.csv("./data/collabs_df_ds.csv", stringsAsFactors = FALSE)

df <- df_raw %>%
  rename(CollabGroup = Country, Year = year, Value = value) %>%
  mutate(iso2c = countrycode(iso3c, "iso3c", "iso2c", warn = FALSE))  # Convert ISO3 → ISO2

# Compute total collaboration values per year
total_per_year <- df %>%
  group_by(Year) %>%
  summarise(TotalValue = sum(Value, na.rm = TRUE)) %>%
  ungroup()

# Merge total values and calculate percentage
df <- df %>%
  left_join(total_per_year, by = "Year") %>%
  mutate(Percentage = (Value / TotalValue) * 100)

################################################
## 2) Shiny UI Construction
################################################

app_theme <- bs_theme(
  version = 5,
  bootswatch = "litera",
  primary = "#2c3e50",
  secondary = "#18bc9c",
  base_font = font_google("Roboto Mono"),
  heading_font = font_google("Roboto Condensed")
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
        card_header("Controls", class = "bg-primary text-white"),
        card_body(
          selectInput(
            inputId  = "collabSelector",
            label    = "Select Collaboration Group:",
            choices  = sort(unique(df$CollabGroup)),
            selected = sort(unique(df$CollabGroup))[1], 
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
            animate = FALSE,
            width   = "100%"
          )
        )
      ),
      
      card(
        style = "margin-bottom: 20px;",
        card_header("Collaboration Summary", class = "bg-primary text-white"),
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
          plotlyOutput("collabLinePlot", height = "50vh"),
          tags$hr(),
          plotlyOutput("collabMap", height = "45vh")
        )
      )
    )
  ),
  
  fluidRow(
    column(
      width = 12,
      card(
        card_header("Detailed Collaboration Data", class = "bg-primary text-white"),
        card_body(
          div(style = "max-height: 400px; overflow-y: auto;", tableOutput("collabTable")),
          htmlOutput("countryDetails")
        )
      )
    )
  ),
  
  tags$footer(
    style = "background-color: #f8f9fa; padding: 15px; margin-top: 20px; border-top: 1px solid #ddd;",
    tags$div(class = "text-center", "Data source: multi-country collaboration dataset")
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
      filter(CollabGroup == input$collabSelector)
  })
  
  output$summaryText <- renderUI({
    data_subset <- collab_data()
    if (nrow(data_subset) == 0) return("No data for this collaboration group.")
    
    all_iso <- data_subset$iso3c %>%
      paste(collapse = "-") %>%
      strsplit("-") %>%
      unlist() %>%
      unique()
    
    n_countries <- length(all_iso)
    
    years_avail  <- sort(unique(data_subset$Year))
    earliestYear <- min(years_avail, na.rm = TRUE)
    latestYear   <- max(years_avail, na.rm = TRUE)
    
    country_names <- countrycode(all_iso, "iso3c", "country.name", warn = FALSE)
    flag_urls <- paste0('<img src="https://flagcdn.com/16x12/', tolower(all_iso), '.png" width="16">')
    
    buttons <- paste0(
      '<button type="button" class="btn btn-outline-secondary btn-sm" onclick="Shiny.setInputValue(\'selectedCountry\', \'', all_iso, '\');">',
      flag_urls, " ", country_names, "</button>"
    )
    
    HTML(glue("Collaboration '{input$collabSelector}' involves {n_countries} countries ",
              "({paste(all_iso, collapse=', ')}).<br>Data spans from year {earliestYear} to {latestYear}.<br>",
              "<b>Countries:</b> <br>{paste(buttons, collapse=' ')}"))
  })
  
  output$collabTable <- renderTable({
    collab_data() %>%
      distinct(Year, Percentage) %>%
      arrange(Year) %>%
      mutate(Percentage = paste0(round(Percentage, 3), " %"))
  })
  
  output$collabMap <- renderPlotly({
    map_subset <- collab_data() %>%
      filter(Year == selected_year()) %>%
      separate_rows(iso2c, sep = "-") 
    
    plot_geo(map_subset) %>%
      add_trace(locations = ~iso2c, z = ~Value, colors = "Blues", text = ~iso2c) %>%
      layout(title = "Collaboration Map")
  })
}

shinyApp(ui, server)