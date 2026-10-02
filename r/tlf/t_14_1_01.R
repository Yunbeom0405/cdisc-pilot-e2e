# Program : t_14_1_01.R
# Purpose : Table 14-1.01 Summary of Populations

source("r/tlf/setup.R")

adsl <- read_adam("adsl") |>
  filter(ITTFL == "Y") |>
  mutate(TRT01P = factor(TRT01P, levels = trt_levels))

pops <- c(
  "Intent-To-Treat (ITT)" = "ITTFL", "Safety" = "SAFFL", "Efficacy" = "EFFFL",
  "Completed Week 24" = "COMP24FL"
)

count_pops <- function(df, .N_col) {
  n <- c(
    sapply(pops, \(v) sum(df[[v]] %in% "Y")),
    "Completed Treatment" = sum(df$EOTSTT %in% "COMPLETED"),
    "Completed Study" = sum(df$EOSSTT %in% "COMPLETED")
  )
  in_rows(.list = as.list(npct(n, .N_col)), .labels = names(n), .formats = rep("xx", length(n)))
}

tbl <- basic_table(show_colcounts = TRUE) |>
  split_cols_by("TRT01P") |>
  add_overall_col("Total") |>
  analyze("USUBJID", afun = count_pops, show_labels = "hidden") |>
  build_table(adsl)

save_tlf(tbl, "t_14_1_01", "Table 14-1.01 Summary of Populations",
  c("Population: Intent-to-Treat. Percentages use N in the column header.",
    "Completed Treatment: EOTSTT = COMPLETED. Completed Study: EOSSTT = COMPLETED."))
