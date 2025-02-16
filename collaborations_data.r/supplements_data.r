library(tidyverse)

df_sup <- read_csv("./data/fig_supplements.csv")

df_sup %>% head()
table(df_sup$source)

df_sup_filtered <- df_sup %>%
  filter(!source %in%  c("FigureS-7c", "FigureS-7f_g"))

df_sup_filtered %>% head()
table(df_sup_filtered$source)

write_csv(df_sup_filtered, "./data/fig_supplements_filtered.csv")
