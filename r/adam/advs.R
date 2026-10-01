# Program : advs.R
# Purpose : Create ADaM ADVS
# Needs   : ADSL

source("r/adam/setup.R")

adsl <- read_adam("adsl")

advs <- read_sdtm("vs") |>
  filter(!is.na(VSSTRESN)) |>
  add_adsl(adsl, exprs(
    SITEID, TRTP = TRT01P, TRTPN = TRT01PN, TRTA = TRT01A, TRTAN = TRT01AN, AGE, AGEGR1,
    AGEGR1N, RACE, RACEN, SEX, SAFFL, TRTSDT, TRTEDT
  )) |>
  mutate(
    PARAMCD = VSTESTCD,
    PARAM = paste0(VSTEST, " (", VSSTRESU, ")"),
    ATPT = VSTPT,
    ATPTN = VSTPTNUM,
    AVAL = VSSTRESN,
    ADT = to_date(VSDTC),
    # baseline: Week 0, height at Screening 1 (SAP 9.2)
    ABLFL = if_else(VISITNUM == if_else(VSTESTCD == "HEIGHT", 1, 3), "Y", NA_character_),
    AVISITN = if_else(ABLFL %in% "Y", 0, avisitn(VISITNUM)),
    AVISIT = case_when(AVISITN == 0 ~ "Baseline", !is.na(AVISITN) ~ paste("Week", AVISITN))
  ) |>
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ADT)) |>
  derive_var_base(by_vars = exprs(USUBJID, PARAMCD, ATPTN), source_var = AVAL, new_var = BASE) |>
  mutate(
    CHG = if_else(AVISITN > 0, AVAL - BASE, NA_real_),
    PCHG = if_else(BASE != 0, CHG / BASE * 100, NA_real_)
  ) |>
  # one record per visit: latest date, then highest sequence
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID, PARAMCD, ATPTN, AVISITN), order = exprs(ADT, VSSEQ),
      new_var = ANL01FL, mode = "last"
    ),
    filter = !is.na(AVISITN)
  ) |>
  # end of treatment: last analysed visit from Week 2 to Week 24
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID, PARAMCD, ATPTN), order = exprs(AVISITN),
      new_var = ANL02FL, mode = "last"
    ),
    filter = ANL01FL == "Y" & between(AVISITN, 2, 24)
  )

advs <- finalize(advs, "ADVS", keys = c("STUDYID", "USUBJID", "PARAMCD", "ATPTN", "ADT", "VSSEQ"))
