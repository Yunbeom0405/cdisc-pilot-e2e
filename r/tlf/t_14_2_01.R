# Program : t_14_2_01.R
# Purpose : Table 14-2.01 Summary of Demographic and Baseline Characteristics

source("r/tlf/setup.R")

adsl <- read_adam("adsl") |>
  filter(ITTFL == "Y") |>
  mutate(TRT01P = factor(TRT01P, levels = trt_levels))

cont <- function(x, .N_col) {
  x <- x[!is.na(x)]
  in_rows(
    .list = list(
      as.character(length(x)), f(mean(x), 1), f(if (length(x) > 1) sd(x) else NA, 2),
      f(median(x), 1), f(min(x), 1), f(max(x), 1)
    ),
    .labels = c("n", "Mean", "SD", "Median", "Min", "Max"),
    .formats = rep("xx", 6)
  )
}

# categories in a fixed order, shown with their own labels
cat_fun <- function(values, labels = values) {
  function(x, .N_col) {
    n <- sapply(values, \(v) sum(x %in% v))
    in_rows(.list = as.list(npct(n, .N_col)), .labels = labels, .formats = rep("xx", length(values)))
  }
}

tbl <- basic_table(show_colcounts = TRUE) |>
  split_cols_by("TRT01P") |>
  add_overall_col("Total") |>
  analyze("AGE", cont, var_labels = "Age (y)", show_labels = "visible", table_names = "age") |>
  analyze("AGEGR1", cat_fun(c("<65", "65-80", ">80")), show_labels = "hidden", table_names = "agegr1") |>
  analyze("SEX", cat_fun(c("M", "F"), c("Male", "Female")), var_labels = "Sex", show_labels = "visible") |>
  analyze("RACE", cat_fun(c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN", "OTHER")),
    var_labels = "Race", show_labels = "visible") |>
  analyze("ETHNIC", cat_fun(c("HISPANIC OR LATINO", "NOT HISPANIC OR LATINO")),
    var_labels = "Ethnicity", show_labels = "visible") |>
  analyze("MMSETOT", cont, var_labels = "MMSE Total Score", show_labels = "visible") |>
  analyze("DURDIS", cont, var_labels = "Duration of Disease (Months)", show_labels = "visible") |>
  analyze("DURDSGR1", cat_fun(c("<12", ">=12")), show_labels = "hidden") |>
  analyze("EDUCLVL", cont, var_labels = "Years of Education", show_labels = "visible") |>
  analyze("WEIGHTBL", cont, var_labels = "Baseline Weight (kg)", show_labels = "visible") |>
  analyze("HEIGHTBL", cont, var_labels = "Baseline Height (cm)", show_labels = "visible") |>
  analyze("BMIBL", cont, var_labels = "Baseline BMI (kg/m2)", show_labels = "visible") |>
  analyze("BMIBLGR1", cat_fun(c("<25", "25-<30", ">=30")), show_labels = "hidden") |>
  build_table(adsl)

save_tlf(tbl, "t_14_2_01", "Table 14-2.01 Summary of Demographic and Baseline Characteristics",
  c("Population: Intent-to-Treat. Percentages use N in the column header.",
    "Duration of disease: months from onset of Alzheimer's disease to Visit 1."))
