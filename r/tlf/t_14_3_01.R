# Program : t_14_3_01.R
# Purpose : Table 14-3.01 ADAS-Cog (11) Change from Baseline to Week 24 - LOCF

source("r/tlf/setup.R")
suppressPackageStartupMessages(library(emmeans))

eff <- read_adam("adqsadas") |>
  filter(PARAMCD == "ACTOT", ANL01FL == "Y", EFFFL == "Y", AVISITN %in% c(0, 24)) |>
  mutate(TRTP = factor(TRTP, levels = trt_levels))

desc <- function(x, .N_col) {
  x <- x[!is.na(x)]
  in_rows(
    .list = list(
      as.character(length(x)),
      paste0(f(mean(x), 1), " (", f(sd(x), 2), ")"),
      paste0(f(median(x), 1), " (", f(min(x), 1), ";", f(max(x), 1), ")")
    ),
    .labels = c("n", "Mean (SD)", "Median (Range)"),
    .formats = rep("xx", 3)
  )
}

tbl <- basic_table(show_colcounts = TRUE) |>
  split_cols_by("TRTP") |>
  analyze("AVAL", desc, var_labels = "Baseline", show_labels = "visible", table_names = "bl") |>
  build_table(filter(eff, AVISITN == 0))

w24 <- filter(eff, AVISITN == 24)
tbl_24 <- basic_table() |>
  split_cols_by("TRTP") |>
  analyze("AVAL", desc, var_labels = "Week 24", show_labels = "visible", table_names = "w24") |>
  analyze("CHG", desc, var_labels = "Change from Baseline", show_labels = "visible", table_names = "chg") |>
  build_table(w24)

# ANCOVA: treatment and site group as factors, baseline as covariate
w24 <- mutate(w24, SITEGR1 = factor(SITEGR1))
dose <- summary(lm(CHG ~ TRTPN + SITEGR1 + BASE, data = w24))$coefficients["TRTPN", "Pr(>|t|)"]
emm <- emmeans(lm(CHG ~ TRTP + SITEGR1 + BASE, data = w24), "TRTP")
est <- contrast(emm, list(
  "Low - Placebo" = c(-1, 1, 0), "High - Placebo" = c(-1, 0, 1), "High - Low" = c(0, -1, 1)
)) |>
  summary(infer = TRUE) |>
  as_tibble()

cell <- function(e, what) {
  switch(what,
    p = pv(e$p.value),
    d = paste0(f(e$estimate, 1), " (", f(e$SE, 2), ")"),
    ci = paste0("(", f(e$lower.CL, 1), ";", f(e$upper.CL, 1), ")")
  )
}
lo <- est[1, ]
hi <- est[2, ]
hl <- est[3, ]

infer <- rbind(
  c("p-value (Dose Response) [1][2]", "", pv(dose), ""),
  c("p-value (Xan - Placebo) [1][3]", "", cell(lo, "p"), cell(hi, "p")),
  c("Diff of LS Means (SE)", "", cell(lo, "d"), cell(hi, "d")),
  c("95% CI", "", cell(lo, "ci"), cell(hi, "ci")),
  c("p-value (Xan High - Xan Low) [1][3]", "", "", cell(hl, "p")),
  c("Diff of LS Means (SE)", "", "", cell(hl, "d")),
  c("95% CI", "", "", cell(hl, "ci"))
)

# descriptive part from rtables, inference rows added below
cells <- rbind(get_formatted_cells(tbl), get_formatted_cells(tbl_24))
labels <- c(make_row_df(tbl)$label, make_row_df(tbl_24)$label)
df <- tibble(LABEL = c(labels, infer[, 1]), C1 = c(cells[, 1], infer[, 2]),
  C2 = c(cells[, 2], infer[, 3]), C3 = c(cells[, 3], infer[, 4])) |>
  mutate(
    ROW = row_number(),
    INDENT = as.integer(!LABEL %in% c("Baseline", "Week 24", "Change from Baseline") & !startsWith(LABEL, "p-value"))
  ) |>
  relocate(ROW)

n <- table(w24$TRTP)
save_df(df, "t_14_3_01", "Table 14-3.01 ADAS-Cog (11) - Change from Baseline to Week 24 - LOCF",
  paste0(trt_levels, " (N=", n, ")"),
  c("Population: Efficacy. [1] ANCOVA with treatment and site group as factors and baseline as covariate.",
    "[2] Treatment (dose) as a continuous variable. [3] Treatment as a categorical variable, no multiplicity adjustment."))
