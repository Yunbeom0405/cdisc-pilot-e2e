# Program : adlb.R
# Purpose : Create ADaM ADLBC (chemistry) and ADLBH (hematology)
# Needs   : ADSL

source("r/adam/setup.R")

adsl <- read_adam("adsl")
lb <- read_sdtm("lb")

make_adlb <- function(cat, ds) {
  adlb <- lb |>
    filter(LBCAT == cat, !is.na(LBSTRESN), LBTESTCD != "HBA1CHGB") |>
    add_adsl(adsl, exprs(
      SITEID, TRTP = TRT01P, TRTPN = TRT01PN, TRTA = TRT01A, TRTAN = TRT01AN, AGE, AGEGR1,
      AGEGR1N, RACE, RACEN, SEX, SAFFL, TRTSDT, TRTEDT, COMP24FL
    )) |>
    mutate(
      PARAMCD = LBTESTCD,
      PARAM = if_else(is.na(LBSTRESU), LBTEST, paste0(LBTEST, " (", LBSTRESU, ")")),
      PARCAT1 = LBCAT,
      AVAL = LBSTRESN,
      A1LO = LBSTNRLO,
      A1HI = LBSTNRHI,
      ADT = to_date(LBDTC),
      # lab baseline is Screening 1, Week -2
      ABLFL = if_else(VISITNUM == 1, "Y", NA_character_),
      AVISITN = if_else(VISITNUM == 1, 0, avisitn(VISITNUM)),
      AVISIT = case_when(AVISITN == 0 ~ "Baseline", !is.na(AVISITN) ~ paste("Week", AVISITN)),
      ONTRTFL = if_else(between(AVISITN, 2, 24), "Y", NA_character_),
      R2A1LO = if_else(A1LO > 0, AVAL / A1LO, NA_real_),
      R2A1HI = if_else(A1HI > 0, AVAL / A1HI, NA_real_),
      # normal range: the limits count as abnormal (SAP 8.3)
      ANRIND = case_when(
        is.na(A1LO) & is.na(A1HI) ~ NA_character_,
        !is.na(A1LO) & AVAL <= A1LO ~ "LOW",
        !is.na(A1HI) & AVAL >= A1HI ~ "HIGH",
        TRUE ~ "NORMAL"
      ),
      AVALCAT1 = case_when(
        is.na(A1LO) & is.na(A1HI) ~ NA_character_,
        !is.na(A1LO) & AVAL < 0.5 * A1LO ~ "LOW",
        !is.na(A1HI) & AVAL > 1.5 * A1HI ~ "HIGH",
        TRUE ~ "NORMAL"
      )
    ) |>
    derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ADT)) |>
    derive_var_base(by_vars = exprs(USUBJID, PARAMCD), source_var = AVAL, new_var = BASE) |>
    derive_var_base(by_vars = exprs(USUBJID, PARAMCD), source_var = ANRIND, new_var = BNRIND) |>
    derive_var_base(by_vars = exprs(USUBJID, PARAMCD), source_var = AVALCAT1, new_var = BASECAT1) |>
    mutate(CHG = if_else(AVISITN > 0, AVAL - BASE, NA_real_)) |>
    # one record per visit: latest date, then highest sequence
    restrict_derivation(
      derivation = derive_var_extreme_flag,
      args = params(
        by_vars = exprs(USUBJID, PARAMCD, AVISITN), order = exprs(ADT, LBSEQ),
        new_var = ANL01FL, mode = "last"
      ),
      filter = !is.na(AVISITN)
    ) |>
    restrict_derivation(
      derivation = derive_var_extreme_flag,
      args = params(
        by_vars = exprs(USUBJID, PARAMCD), order = exprs(AVISITN),
        new_var = ANL02FL, mode = "last"
      ),
      filter = ANL01FL == "Y" & between(AVISITN, 2, 24)
    )

  # change from the previous analysed visit larger than half the normal range
  crit <- adlb |>
    filter(ANL01FL == "Y") |>
    arrange(USUBJID, PARAMCD, AVISITN) |>
    group_by(USUBJID, PARAMCD) |>
    mutate(
      prev = lag(AVAL),
      ok = row_number() > 1 & !is.na(A1LO) & !is.na(A1HI),
      CRIT1 = if_else(ok, "Change from previous visit >50% of (ULN-LLN)", NA_character_),
      CRIT1FL = case_when(ok & abs(AVAL - prev) > 0.5 * (A1HI - A1LO) ~ "Y", ok ~ "N")
    ) |>
    ungroup() |>
    select(USUBJID, PARAMCD, ADT, LBSEQ, CRIT1, CRIT1FL)

  adlb |>
    left_join(crit, by = c("USUBJID", "PARAMCD", "ADT", "LBSEQ")) |>
    finalize(ds, keys = c("STUDYID", "USUBJID", "PARAMCD", "ADT", "LBSEQ"))
}

adlbc <- make_adlb("CHEMISTRY", "ADLBC")
adlbh <- make_adlb("HEMATOLOGY", "ADLBH")
