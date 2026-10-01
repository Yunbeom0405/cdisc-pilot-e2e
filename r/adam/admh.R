# Program : admh.R
# Purpose : Create ADaM ADMH
# Needs   : ADSL

source("r/adam/setup.R")

adsl <- read_adam("adsl")

admh <- read_sdtm("mh") |>
  add_adsl(adsl, exprs(
    SITEID, TRTP = TRT01P, TRTPN = TRT01PN, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX, SAFFL, ITTFL
  ))

# the primary diagnosis is not coded
first_mh <- function(dat, flag, by) {
  restrict_derivation(
    dat,
    derivation = derive_var_extreme_flag,
    args = params(by_vars = by, order = exprs(MHSEQ), new_var = !!flag, mode = "first"),
    filter = MHCAT != "PRIMARY DIAGNOSIS"
  )
}

admh <- admh |>
  first_mh(sym("AOCCSFL"), exprs(USUBJID, MHBODSYS)) |>
  first_mh(sym("AOCCPFL"), exprs(USUBJID, MHBODSYS, MHDECOD))

admh <- finalize(admh, "ADMH", keys = c("STUDYID", "USUBJID", "MHSEQ"))
