library(tidyverse)
library(countrycode)

# Set path to directory containing TSV files
data_dir <- "./data/"

# Get list of TSV files
files <- list.files(data_dir, pattern = "\\.tsv$", full.names = TRUE)

process_file <- function(file) {
  # Read and process each file
  read_tsv(file, col_types = cols(), skip = 1,
           col_names = c("country_code", as.character(1981:2022))) %>%
    pivot_longer(-country_code, names_to = "year", values_to = "value",
                 values_drop_na = TRUE) %>%
    mutate(
      source = tools::file_path_sans_ext(basename(file)),
      # Process country codes
      codes = strsplit(country_code, ","),
      country_names = map(codes, ~ {
        names <- countrycode(.x, "iso2c", "country.name", warn = FALSE)
        ifelse(is.na(names), "Unknown", names)
      }),
      Country = map_chr(country_names, ~ paste(.x, collapse = "-")),
      iso3c = map_chr(codes, ~ {
        if (length(.x) == 0) return(NA_character_)
        code <- countrycode(.x[1], "iso2c", "iso3c", warn = FALSE)
        ifelse(is.na(code), NA_character_, code)
      })
    ) %>%
    select(Country, year, value, source, iso3c) %>%
    mutate(year = as.integer(year))
}

# Combine all files into one dataframe
final_df <- map_dfr(files, process_file)

# View result
head(final_df)
colnames(final_df)

# Save the final dataframe to a CSV file
write_csv(final_df, "./data/collabs_df.csv")

############### ------------

# Install packages if not already installed
install.packages(c("dplyr", "stringr", "countrycode"))

# Load libraries
library(dplyr)
library(stringr)
library(countrycode)

# Extract unique country combinations
unique_countries <- df %>%
  distinct(Country) %>%
  pull(Country)

# Function to convert country names to ISO3 codes
get_iso3 <- function(country_str) {
  # Split the string by "-" and trim whitespace
  countries <- str_split(country_str, "-")[[1]] %>%
    str_trim()

  # Convert to ISO3 codes
  iso_codes <- countrycode(countries, origin = 'country.name', destination = 'iso3c')

  # Handle unmatched countries
  if(any(is.na(iso_codes))) {
    unmatched <- countries[is.na(iso_codes)]
    warning(paste("Unmatched country names:", paste(unmatched, collapse = ", ")))
  }

  return(iso_codes)
}

# Apply the function to all unique country combinations
pair_to_iso <- setNames(
  lapply(unique_countries, get_iso3),
  unique_countries
)

print(pair_to_iso)

##############3

library(tidyverse)
library(countrycode)

# Modified processing function to generate country pairs
process_file <- function(file) {
  read_tsv(file, col_types = cols(), skip = 1,
           col_names = c("country_code", as.character(1981:2022))) %>%
    pivot_longer(-country_code, names_to = "year", values_to = "value",
                 values_drop_na = TRUE) %>%
    filter(value > 0) %>%
    mutate(
      source = tools::file_path_sans_ext(basename(file)),
      # Split and convert country codes
      iso3_list = map(strsplit(country_code, ","), ~ {
        codes <- countrycode(.x, "iso2c", "iso3c", warn = FALSE)
        codes[!is.na(codes)]  # Remove invalid codes
      })
    ) %>%
    # Generate all unique country pairs
    mutate(
      pairs = map(iso3_list, ~ {
        if(length(.x) >= 2) {
          combn(.x, 2, simplify = FALSE) %>%
            map(~ sort(.) %>% set_names(c("iso1", "iso2")))
        } else {
          list(NULL)
        }
      })
    ) %>%
    unnest(pairs, keep_empty = TRUE) %>%
    filter(!is.na(iso1)) %>%
    # Create combined country name
    mutate(
      Country = map2_chr(iso1, iso2, ~ {
        name1 <- countrycode(.x, "iso3c", "country.name", warn = FALSE)
        name2 <- countrycode(.y, "iso3c", "country.name", warn = FALSE)
        paste(coalesce(name1, "Unknown"), coalesce(name2, "Unknown"), sep = "-")
      })
    ) %>%
    select(Country, year, value, source, iso1, iso2)
}

# Process all files
pair_df <- map_dfr(files, process_file)

# Create named list of ISO pairs (equivalent to your manual mapping)
pair_to_iso <- pair_df %>%
  distinct(Country, iso1, iso2) %>%
  {setNames(map2(.$iso1, .$iso2, c), .$Country)}

# Example output:
head(pair_to_iso)
# $`United Arab Emirates-United States`
# [1] "ARE" "USA"
#
# $`Armenia-Russia`
# [1] "ARM" "RUS"
#
# $`Czechia-Finland`
# [1] "CZE" "FIN"
# ...

# Resulting dataframe structure:
head(pair_df)
# # A tibble: 6 × 6
#   Country                     year  value source                          iso1  iso2 
#   <chr>                      <int>  <dbl> <chr>                           <chr> <chr>
# 1 United Arab Emirates-Austria  1987    11 absolute_counting_colabs_metal… ARE   AUT  
# 2 United Arab Emirates-Egypt    1987    11 absolute_counting_colabs_metal… ARE   EGY  
# 3 United Arab Emirates-Germany  1987    11 absolute_counting_colabs_metal… ARE   DEU  
# 4 Armenia-Russia                2005     5 absolute_counting_colabs_metal… ARM   RUS  
# 5 Armenia-South Korea           2005     5 absolute_counting_colabs_metal… ARM   KOR  
# 6 Armenia-Uzbekistan            2005     5 absolute_counting_colabs_metal… ARM   UZB
