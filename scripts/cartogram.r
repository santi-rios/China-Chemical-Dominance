# install.packages("sf")
library(sf)
# install.packages("dplyr")
library(dplyr)
# install.packages("ggplot2")
library(ggplot2)
# install.packages("cartogram")
library(cartogram)

######### Data Preparation #########
# Directly read the CSV from the URL to avoid using download.file
data_url <- "https://raw.githubusercontent.com/santi-rios/China-Chemical-Rise/refs/heads/main/data/merged_figure1.csv"


df <- read.csv(data_url, stringsAsFactors = FALSE) %>%
  mutate(
    continent = countrycode(iso3c, "iso3c", "continent", 
                           custom_match = c(USA = "North America"),
                           nomatch = "Other")
  )



# Load world spatial data using rnaturalearth with improved filtering
world_sf <- ne_countries(scale = "medium", returnclass = "sf") %>%
  select(iso_a3, name, geometry) %>%
  filter(!iso_a3 %in% c("ATA")) %>% # Exclude Antarctica
  rename(Country = "name", iso3c = "iso_a3")

# Base map
ggplot(world_sf) +
  geom_sf()

# Filter data for the selected facet and year
map_data <- df %>%
  filter(source == "Figure1-a") 
# %>%
#   select(iso3c, Value, Year)

# Merge with spatial data
merged_sf <- world_sf %>%
  # left_join(map_data, by = c("iso_a3" = "iso3c")) %>%
  full_join(map_data) %>%
  # Replace NA and zero values with a small positive number to ensure cartogram_cont works properly
  mutate(Value = ifelse(is.na(Value) | Value <= 0, 0.1, Value)) %>%
  filter(iso3c %in% c("RUS", "CHN", "JPN")) %>%
  filter(!Country == "China w/o US") %>%
  na.omit()

prov_3857 <- st_transform(merged_sf, 3857)

# dk_map <- sf::st_cast(prov_3857, "MULTIPOLYGON")

prov_3857_data_cartog_cont <- cartogram_cont(prov_3857, weight = "Value")

head(prov_3857_data_cartog_cont)

prov_3857_data_cartog_cont  %>%
  filter(Year %in% c(2020)) |> 
  # group_by(name, Year) %>%
ggplot() +
  geom_sf(
    # data = merged_sf,
    aes(fill = Value)
    # color = "white"
    # linewidth = 2
  ) +
  facet_grid(~ Year)

# scale_fill_viridis(
  #   option = "plasma",
  #   na.value = "grey90",
  #   name = "Value"
  # ) +
  # theme_void() +
  # labs(title = paste("Cartogram -", axis_labels()$map_title, "(", input$year, ")")) +
  # theme(
  #   plot.title = element_text(hjust = 0.5, size = 16, face = "bold")
  # )

# ggplotly(mainland)

carto <- tryCatch({
  cartogram_cont(merged_sf, "Value", itermax = 3)  # Reduced itermax for speed
}, error = function(e) {
  merged_sf  # Return original if cartogram fails
})

tm_shape(carto) +
  tm_fill("Value") +
  tm_borders()

## Clean script ----
library(sf)
library(dplyr)
library(ggplot2)
library(cartogram)
library(gganimate)
library(gifski)
library(rnaturalearth)
library(purrr)

# Load and prepare data
data_url <- "./data/fig_1_all_co.csv"

df <- read.csv(data_url) %>%
  mutate(Value = ifelse(Value <= 0 | is.na(Value), 0.1, Value))

# Load world map data
world_sf <- ne_countries(scale = "medium", returnclass = "sf") %>%
  select(iso_a3, name, geometry) %>%
  filter(iso_a3 != "ATA") %>%
  rename(iso3c = iso_a3, Country = name)

# Merge data with spatial data
merged_sf <- world_sf %>%
  inner_join(df, by = "iso3c") %>%
  filter(!st_is_empty(geometry)) %>%
  st_transform(3857)

# Function to process each source
create_source_animation <- function(source_data) {
  current_source <- unique(source_data$source)
  if (length(current_source) == 0) {
    message("Skipping group with no source information.")
    return()
  }
  
  # Process each year
  cartograms <- source_data %>%
    group_by(Year) %>%
    group_split() %>%
    map_df(~{
      valid_data <- .x %>% filter(!is.na(geometry), Value > 0)
      
      if (nrow(valid_data) == 0) return(NULL)
      
      tryCatch({
        cart <- cartogram_cont(valid_data, "Value", itermax = 5)
        # Ensure cartogram has the same columns as valid_data
        cart %>% select(names(valid_data))
      }, error = function(e) {
        message(paste("Cartogram failed for", current_source, "year", .x$Year[1], ":", e$message))
        valid_data
      })
    })
  
  if (is.null(cartograms) || nrow(cartograms) == 0) {
    message("No valid cartogram data for source: ", current_source)
    return()
  }
  
  # Create animation
  animation <- ggplot(cartograms) +
    geom_sf(aes(fill = Value), color = "white", linewidth = 0.2) +
    scale_fill_viridis_c(option = "plasma", name = "Value") +
    transition_states(Year, transition_length = 1, state_length = 2) +
    labs(title = paste('Source:', current_source, 'Year: {closest_state}')) +
    theme_void() +
    theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"))
  
  animate(animation, 
          duration = 15, 
          fps = 8, 
          width = 1000, 
          height = 600,
          renderer = gifski_renderer())
  
  anim_save(paste0("cartogram_", gsub("[^A-Za-z0-9]", "_", current_source), ".gif"))
}

# Create animations for each source
merged_sf %>%
  group_by(source) %>%
  group_split() %>%
  walk(create_source_animation)


## DOS ----
# Install required packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(sf, rnaturalearth, cartogram, ggplot2, gifski, dplyr, tidyr)

# Read and prepare data
data <- read.csv("./data/fig_1_all_cou.csv") %>%
  mutate(Value = as.numeric(Value)) %>%
  filter(!is.na(Value))

# Get world map data
world <- ne_countries(scale = "medium", returnclass = "sf") %>%
  select(iso_a3, name, geometry) %>%
  st_make_valid()

# Merge with your data
merged <- world %>%
  left_join(data, by = c("iso_a3" = "iso3c")) %>%
  filter(!is.na(Year), !is.na(Value))

# Create cartograms for each year
years <- sort(unique(merged$Year))
dir.create("cartograms", showWarnings = FALSE)

for (year in years) {
  year_data <- merged %>% 
    filter(Year == year) %>%
    st_transform("+proj=merc")  # Mercator projection
  
  tryCatch({
    carto <- cartogram_cont(year_data, "Value", itermax = 15)
    
    p <- ggplot(carto) +
      geom_sf(aes(fill = Value), color = "gray30", size = 0.2) +
      scale_fill_viridis_c(option = "plasma", name = "Value") +
      labs(title = paste("Year:", year)) +
      theme_void() +
      theme(plot.title = element_text(hjust = 0.5, size = 16))
    
    ggsave(paste0("cartograms/", year, ".png"), p, 
           width = 12, height = 8, dpi = 100)
  }, error = function(e) message("Skipping year ", year, ": ", e$message))
}

# Create GIF
png_files <- list.files("cartograms", pattern = "\\.png$", full.names = TRUE)
gifski(png_files, "cartogram_animation.gif", 
       width = 1200, height = 800, delay = 1, loop = TRUE)
