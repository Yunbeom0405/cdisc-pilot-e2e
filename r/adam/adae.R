# Program : adae.R
# Purpose : Create ADaM ADAE
# Needs   : ADSL (run adsl.R first)

source("r/adam/setup.R")

adsl <- read_adam("adsl")
ae <- read_sdtm("ae")
relrec <- read_sdtm("relrec")
ds <- read_sdtm("ds")

# dermatologic events, CSR Table 12-2
derm <- c(
  paste("APPLICATION SITE", c(
    "BLEEDING", "DERMATITIS", "DESQUAMATION", "DISCHARGE", "DISCOLOURATION", "ERYTHEMA",
    "INDURATION", "IRRITATION", "PAIN", "PERSPIRATION", "PRURITUS", "REACTION", "SWELLING",
    "URTICARIA", "VESICLES", "WARMTH"
  )),
  "ACTINIC KERATOSIS", "BLISTER", "DERMATITIS CONTACT", "DRUG ERUPTION", "ERYTHEMA", "PRURITUS",
  "PRURITUS GENERALISED", "RASH", "RASH ERYTHEMATOUS", "RASH MACULO-PAPULAR", "RASH PRURITIC",
  "SKIN EXFOLIATION", "SKIN IRRITATION", "SKIN ODOUR ABNORMAL", "SKIN ULCER", "URTICARIA"
)

# AEs linked in RELREC to a treatment stop for ADVERSE EVENT
dc_ae <- relrec |>
  filter(RDOMAIN == "DS") |>
  mutate(DSSEQ = as.numeric(IDVARVAL)) |>
  inner_join(filter(ds, DSDECOD == "ADVERSE EVENT"), by = c("USUBJID", "DSSEQ")) |>
  select(USUBJID, RELID) |>
  inner_join(filter(relrec, RDOMAIN == "AE"), by = c("USUBJID", "RELID")) |>
  distinct(USUBJID, AESPID = IDVARVAL)

adae <- ae |>
  add_adsl(adsl, exprs(
    SITEID, TRTA = TRT01A, TRTAN = TRT01AN, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX, SAFFL,
    TRTSDT, TRTEDT
  )) |>
  # partial start date: first of month/year, or first dose if in the same month/year
  derive_vars_dt(
    new_vars_prefix = "AST", dtc = AESTDTC,
    highest_imputation = "M", date_imputation = "first", min_dates = exprs(TRTSDT)
  ) |>
  derive_vars_dt(new_vars_prefix = "AEN", dtc = AEENDTC) |>
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ASTDT, AENDT)) |>
  mutate(
    AESEVN = c(MILD = 1, MODERATE = 2, SEVERE = 3)[AESEV] |> unname(),
    RELGR1 = if_else(AEREL %in% c("REMOTE", "NONE"), "NOT RELATED", "RELATED"),
    CQ01NAM = if_else(AEDECOD %in% derm, "DERMATOLOGIC EVENTS", NA_character_),
    ADURN = as.numeric(AENDT - ASTDT) + 1,
    ADURU = if_else(!is.na(ADURN), "DAYS", NA_character_),
    TRTEMFL = if_else(!is.na(TRTSDT) & ASTDT >= TRTSDT, "Y", NA_character_),
    DCTRTFL = if_else(paste(USUBJID, AESPID) %in% paste(dc_ae$USUBJID, dc_ae$AESPID), "Y", NA_character_)
  )

# first occurrence flags among treatment-emergent events
occ <- function(dat, flag, by, order, filter = TRTEMFL == "Y") {
  restrict_derivation(
    dat,
    derivation = derive_var_extreme_flag,
    args = params(by_vars = by, order = order, new_var = !!flag, mode = "first"),
    filter = {{ filter }}
  )
}
by_first <- exprs(ASTDT, AESEQ)
by_sev <- exprs(desc(AESEVN), ASTDT, AESEQ)

adae <- adae |>
  occ(sym("AOCCFL"), exprs(USUBJID), by_first) |>
  occ(sym("AOCCSFL"), exprs(USUBJID, AEBODSYS), by_first) |>
  occ(sym("AOCCPFL"), exprs(USUBJID, AEBODSYS, AEDECOD), by_first) |>
  occ(sym("AOCCIFL"), exprs(USUBJID), by_sev) |>
  occ(sym("AOCCSIFL"), exprs(USUBJID, AEBODSYS), by_sev) |>
  occ(sym("AOCCPIFL"), exprs(USUBJID, AEBODSYS, AEDECOD), by_sev) |>
  occ(sym("AOCC01FL"), exprs(USUBJID), by_first, TRTEMFL == "Y" & !is.na(CQ01NAM))

adae <- finalize(adae, "ADAE", keys = c("STUDYID", "USUBJID", "AESEQ"))
