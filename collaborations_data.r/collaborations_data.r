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

#######

library(tidyverse)
library(countrycode)

# 1. Read your original collabs_df.csv
df_orig <- read_csv("./data/collabs_df.csv")

# 2. Rename columns to match Shiny code, if needed
#    (Your Shiny app expects columns named "Year" and "Value", capitalized.)
df_orig <- df_orig %>%
  rename(Year = year,
         Value = value)

# 3. Expand each multi-country string. We will:
#      - Keep the original "Country" column as "CollabGroup" to indicate the entire group
#      - Split it into single countries
#      - For each single country, get the correct iso3c code
df_expanded <- df_orig %>%
  # Some of your "Country" fields have one country, others have many separated by "-"
  mutate(country_list = str_split(Country, pattern = "-")) %>%
  # Rename original Country -> CollabGroup
  rename(CollabGroup = Country) %>%
  # Expand so that each row is for exactly one single country
  unnest(country_list) %>%
  # Trim whitespace just in case
  mutate(country_list = str_trim(country_list)) %>%
  # Get iso3c codes from actual country names
  mutate(iso3c_expanded = countrycode(country_list, 
                                      origin = "country.name",
                                      destination = "iso3c",
                                      warn = FALSE)) %>%
  # Reorder columns (optional)
  select(CollabGroup, country_list, iso3c_expanded, Year, Value, source) %>%
  # For clarity, rename to final desired names
  rename(Country = country_list,
         iso3c   = iso3c_expanded)

# 4. (Optional) You can handle "Unknown" or NA iso3c as you wish.
#    For example, if "Unknown" was a placeholder in the original data, you can keep or remove those:
# df_expanded <- df_expanded %>% filter(Country != "Unknown")

# 5. Save the new expanded dataset
write_csv(df_expanded, "./data/collabs_expanded.csv")

df <- read_csv("./data/collabs_expanded.csv")


########
library(tidyverse)
library(countrycode)

# Set path to directory containing TSV files
data_dir <- "./data/"

# Get list of TSV files
files <- list.files(data_dir, pattern = "\\.tsv$", full.names = TRUE)


process_file <- function(file) {
  read_tsv(file, col_types = cols(), skip = 1,
           col_names = c("country_code", as.character(1981:2022))) %>%
    pivot_longer(-country_code, names_to = "year", values_to = "value",
                 values_drop_na = TRUE) %>%
    mutate(
      source = tools::file_path_sans_ext(basename(file)),
      codes = strsplit(country_code, ",")
    ) %>%
    mutate(
      code_name_pairs = map(codes, ~ {
        names <- countrycode(.x, "iso2c", "country.name", warn = FALSE)
        names <- ifelse(is.na(names), "Unknown", names)
        data.frame(code = .x, name = names, stringsAsFactors = FALSE) %>%
          arrange(name)
      }),
      sorted_codes = map(code_name_pairs, ~ .x$code),
      sorted_names = map(code_name_pairs, ~ .x$name),
      Country = map_chr(sorted_names, ~ paste(unique(.x), collapse = "-")),
      iso3c = map_chr(sorted_codes, ~ {
        codes_iso3c <- countrycode(.x, "iso2c", "iso3c", warn = FALSE)
        valid_codes <- na.omit(codes_iso3c)
        if (length(valid_codes) == 0) NA_character_ else paste(valid_codes, collapse = "-")
      })
    ) %>%
    select(Country, year, value, source, iso3c) %>%
    mutate(year = as.integer(year))
}

# Combine all files and save
final_df <- map_dfr(files, process_file)
write_csv(final_df, "./data/collabs_df_ds.csv")

## Filter Namibia as its causing problems
final_df <- read.csv("./data/collabs_df_ds.csv")
# colnames(final_df)
final_df <- final_df %>% filter(str_detect(CollabGroup, "Namibia") == FALSE)

str(final_df)
# Save the filtered data

final_df <- final_df %>% select(-X)

write.csv(final_df, "./data/collabs_df_ds.csv", row.names = FALSE)  
