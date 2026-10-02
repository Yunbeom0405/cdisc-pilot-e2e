# Program : t_a3.R
# Purpose : Table A3 Treatment Emergent Adverse Events by Maximum Severity

source("r/tlf/setup.R")

adsl <- read_adam("adsl") |> filter(SAFFL == "Y")
bign <- table(factor(adsl$TRT01A, levels = trt_levels))

te <- read_adam("adae") |>
  filter(TRTEMFL == "Y", SAFFL == "Y") |>
  mutate(TRTA = factor(TRTA, levels = trt_levels))

# worst severity per subject: overall (blank SOC) and within SOC
mx <- bind_rows(mutate(te, SOC = ""), mutate(te, SOC = AEBODSYS)) |>
  group_by(SOC, USUBJID, TRTA) |>
  summarise(mxsev = max(AESEVN), .groups = "drop")

# sev 0 = any severity
count_n <- function(soc, sev, trt) {
  sum(mx$SOC == soc & mx$TRTA == trt & (sev == 0 | mx$mxsev == sev))
}

df <- expand_grid(SOC = sort(unique(mx$SOC)), sev = 0:3) |>
  rowwise() |>
  mutate(
    n_1 = count_n(SOC, sev, trt_levels[1]),
    n_2 = count_n(SOC, sev, trt_levels[2]),
    n_3 = count_n(SOC, sev, trt_levels[3])
  ) |>
  ungroup() |>
  mutate(
    ROW = row_number(),
    LABEL = case_when(
      sev > 0 ~ c("Mild", "Moderate", "Severe")[pmax(sev, 1)],
      SOC == "" ~ "ANY TEAE",
      TRUE ~ SOC
    ),
    INDENT = as.integer(sev > 0),
    C1 = npct(n_1, bign[1], 1),
    C2 = npct(n_2, bign[2], 1),
    C3 = npct(n_3, bign[3], 1)
  ) |>
  select(ROW, LABEL, INDENT, C1:C3)

save_df(df, "t_a3", "Table A3 Treatment Emergent Adverse Events by Maximum Severity",
  paste0(trt_levels, " (N=", bign, ")"),
  c("Population: Safety. Treatment emergent: events which start on or after the first dose. Coded with MedDRA.",
    "Cells: subjects (percent of N) by their worst severity within the body system."))
