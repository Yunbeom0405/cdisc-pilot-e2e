# Program : adqscibc.R
# Purpose : Create ADaM ADQSCIBC (CIBIC+)
# Needs   : ADSL

source("r/adam/setup.R")

adsl <- read_adam("adsl")

# no baseline: CIBIC+ rates change from baseline
adqscibc <- read_sdtm("qs") |>
  filter(QSCAT == "ADCS-CGIC", !is.na(QSSTRESN)) |>
  mutate(PARAMCD = "CIBIC", PARAM = "CIBIC+ Score", AVAL = QSSTRESN, AVALC = QSORRES) |>
  add_adsl(adsl, exprs(
    SITEID, SITEGR1, TRTP = TRT01P, TRTPN = TRT01PN, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX,
    ITTFL, EFFFL, COMP24FL, TRTSDT, TRTEDT
  )) |>
  mutate(ADT = to_date(QSDTC)) |>
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ADT)) |>
  add_window(baseline = FALSE) |>
  add_locf("CIBIC")

adqscibc <- finalize(adqscibc, "ADQSCIBC", keys = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN", "ADT", "DTYPE"))
