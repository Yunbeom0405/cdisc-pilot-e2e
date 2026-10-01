# Program : adqsadas.R
# Purpose : Create ADaM ADQSADAS (ADAS-Cog 11)
# Needs   : ADSL

source("r/adam/setup.R")

adsl <- read_adam("adsl")

# the 11 items of ADAS-Cog(11) and their maximum scores
items <- tribble(
  ~QSTESTCD, ~max, ~PARAM,
  "ACITM01", 10, "Word Recall Task",
  "ACITM02", 5, "Naming Objects And Fingers",
  "ACITM04", 5, "Commands",
  "ACITM05", 5, "Constructional Praxis",
  "ACITM06", 5, "Ideational Praxis",
  "ACITM07", 8, "Orientation",
  "ACITM08", 12, "Word Recognition",
  "ACITM11", 5, "Spoken Language Ability",
  "ACITM12", 5, "Comprehension of Spoken Language",
  "ACITM13", 5, "Word Finding Difficulty",
  "ACITM14", 5, "Recall of Test Instructions"
)

adas <- read_sdtm("qs") |>
  filter(QSCAT == "ALZHEIMER'S DISEASE ASSESSMENT SCALE") |>
  inner_join(items, by = "QSTESTCD")

# total: prorated to 0-70 if 1-3 items are missing, null if 4 or more
total <- adas |>
  group_by(USUBJID, VISITNUM, QSDTC) |>
  summarise(
    VISIT = max(VISIT),
    n = sum(!is.na(QSSTRESN)),
    AVAL = if_else(n >= 8, sum(QSSTRESN, na.rm = TRUE) * 70 / sum(max[!is.na(QSSTRESN)]), NA_real_),
    .groups = "drop"
  ) |>
  mutate(PARAMCD = "ACTOT", PARAM = "ADAS-Cog(11) Total Score")

adqsadas <- bind_rows(
  total,
  adas |> filter(!is.na(QSSTRESN)) |> mutate(PARAMCD = QSTESTCD, AVAL = QSSTRESN)
) |>
  select(-STUDYID) |>
  add_adsl(adsl, exprs(
    STUDYID, SITEID, SITEGR1, TRTP = TRT01P, TRTPN = TRT01PN, AGE, AGEGR1, AGEGR1N, RACE, RACEN,
    SEX, ITTFL, EFFFL, COMP24FL, TRTSDT, TRTEDT
  )) |>
  mutate(ADT = to_date(QSDTC)) |>
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ADT)) |>
  add_window() |>
  mutate(ABLFL = if_else(AVISITN == 0 & ANL01FL %in% "Y", "Y", NA_character_)) |>
  add_locf("ACTOT") |>
  derive_var_base(by_vars = exprs(USUBJID, PARAMCD), source_var = AVAL, new_var = BASE) |>
  mutate(
    CHG = if_else(AVISITN > 0, AVAL - BASE, NA_real_),
    PCHG = if_else(BASE != 0, CHG / BASE * 100, NA_real_)
  )

adqsadas <- finalize(adqsadas, "ADQSADAS", keys = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN", "ADT", "DTYPE"))
