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
