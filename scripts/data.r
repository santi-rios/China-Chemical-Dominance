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
  "\\bNAM\\b" = "NA"
  # "\\bUK\\b" = "United Kingdom",
  # "\\bCN\\b" = "China"
)

# Clean the Country column using regex to match whole words

data_clean <- df %>%
  mutate(Country = str_replace_all(Country, country_replacement))


df_fig1 <- data_clean %>%
  filter(source == "Figure-12-a_b") %>%
  mutate(Country = as.factor(Country), source = as.factor(source)) %>%
  mutate(Country = ifelse(is_iso2(Country),
                          countrycode(Country, "iso2c", "country.name"),
                          Country)) %>%
  na.omit()

# mutate(iso3c = countrycode(Variable, origin = "country.name", destination = "iso3c"))

str(df_fig1)
tail(df_fig1)
sort(unique(df_fig1$Country))

# Save the cleaned dataset
# write.csv(df, "./data/countryAll_participation_growth_cs.csv", row.names = FALSE)

