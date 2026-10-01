# Program : adsl.R
# Purpose : Create ADaM ADSL

source("r/adam/setup.R")

dm <- read_sdtm("dm")
ex <- read_sdtm("ex")
ds <- read_sdtm("ds")
sv <- read_sdtm("sv")
vs <- read_sdtm("vs")
qs <- read_sdtm("qs")
mh <- read_sdtm("mh")
sc <- read_sdtm("sc")

trtn <- c("Placebo" = 0, "Xanomeline Low Dose" = 54, "Xanomeline High Dose" = 81)
racen <- c("WHITE" = 1, "BLACK OR AFRICAN AMERICAN" = 2, "ASIAN" = 3, "OTHER" = 4)

# sites with fewer than 3 randomized subjects in any arm are pooled
sitegr <- dm |>
  filter(!is.na(ARM)) |>
  count(SITEID, ARM) |>
  group_by(SITEID) |>
  summarise(SITEGR1 = if_else(n() < 3 | min(n) < 3, "900", first(SITEID)))

adsl <- dm |>
  select(-DOMAIN) |>
  left_join(sitegr, by = "SITEID") |>
  mutate(
    TRT01P = ARM,
    TRT01A = ACTARM,
    TRT01PN = unname(trtn[TRT01P]),
    TRT01AN = unname(trtn[TRT01A]),
    # 6 subjects have no final dose date; RFENDTC is their last visit
    TRTEDTC = coalesce(RFXENDTC, RFENDTC)
  ) |>
  derive_vars_dt(new_vars_prefix = "TRTS", dtc = RFXSTDTC) |>
  derive_vars_dt(new_vars_prefix = "TRTE", dtc = TRTEDTC) |>
  derive_var_trtdurd()

# cumulative dose: daily dose times days of each EX interval
dose <- ex |>
  derive_vars_merged(dataset_add = adsl, by_vars = exprs(USUBJID), new_vars = exprs(TRTEDT)) |>
  mutate(days = as.numeric(coalesce(to_date(EXENDTC), TRTEDT) - to_date(EXSTDTC)) + 1) |>
  group_by(USUBJID) |>
  summarise(CUMDOSE = sum(EXDOSE * days))

# efficacy population: baseline and post-baseline ADAS-Cog, post-baseline CIBIC+
done <- filter(qs, is.na(QSSTAT))
adas_bl <- done |> filter(QSCAT == "ALZHEIMER'S DISEASE ASSESSMENT SCALE", VISITNUM == 3) |> pull(USUBJID)
adas_post <- done |> filter(QSCAT == "ALZHEIMER'S DISEASE ASSESSMENT SCALE", VISITNUM > 3) |> pull(USUBJID)
cibic_post <- done |> filter(QSCAT == "ADCS-CGIC", VISITNUM > 3) |> pull(USUBJID)

attended <- function(v) sv |> filter(VISITNUM == v, SVPRESP == "Y") |> pull(USUBJID)

# MMSE total: null unless all 6 items are present
mmse <- qs |>
  filter(QSCAT == "MINI-MENTAL STATE", QSLOBXFL == "Y") |>
  group_by(USUBJID) |>
  summarise(MMSETOT = if_else(sum(!is.na(QSSTRESN)) == 6, sum(QSSTRESN), NA_real_))

dispo <- function(scat) {
  ds |>
    filter(DSCAT == "DISPOSITION EVENT", DSSCAT == scat) |>
    select(USUBJID, DSDECOD, DSSTDTC)
}

adsl <- adsl |>
  left_join(dose, by = "USUBJID") |>
  left_join(mmse, by = "USUBJID") |>
  derive_vars_merged(
    dataset_add = vs, by_vars = exprs(USUBJID),
    filter_add = VSTESTCD == "HEIGHT" & VISITNUM == 1, new_vars = exprs(HEIGHTBL = VSSTRESN)
  ) |>
  derive_vars_merged(
    dataset_add = vs, by_vars = exprs(USUBJID),
    filter_add = VSTESTCD == "WEIGHT" & VISITNUM == 3, new_vars = exprs(WEIGHTBL = VSSTRESN)
  ) |>
  derive_vars_merged(
    dataset_add = sv, by_vars = exprs(USUBJID),
    filter_add = VISITNUM == 1, new_vars = exprs(VISIT1DTC = SVSTDTC)
  ) |>
  derive_vars_merged(
    dataset_add = ds, by_vars = exprs(USUBJID),
    filter_add = DSDECOD == "RANDOMIZED", new_vars = exprs(RANDDTC = DSSTDTC)
  ) |>
  derive_vars_merged(
    dataset_add = dispo("STUDY TREATMENT"), by_vars = exprs(USUBJID),
    new_vars = exprs(EOTDECOD = DSDECOD)
  ) |>
  derive_vars_merged(
    dataset_add = dispo("STUDY PARTICIPATION"), by_vars = exprs(USUBJID),
    new_vars = exprs(EOSDECOD = DSDECOD, EOSDTC = DSSTDTC)
  ) |>
  derive_vars_merged(
    dataset_add = mh, by_vars = exprs(USUBJID),
    filter_add = MHCAT == "PRIMARY DIAGNOSIS", new_vars = exprs(ONSETDTC = MHSTDTC)
  ) |>
  derive_vars_merged(
    dataset_add = sc, by_vars = exprs(USUBJID),
    filter_add = SCTESTCD == "EDUYRNUM", new_vars = exprs(EDUCLVL = SCSTRESN)
  ) |>
  # partial onset date: first of the month or year, no flag (name too long)
  derive_vars_dt(
    new_vars_prefix = "DISONS", dtc = ONSETDTC,
    highest_imputation = "M", date_imputation = "first", flag_imputation = "none"
  ) |>
  mutate(
    AVGDD = if_else(TRTDURD > 0, CUMDOSE / TRTDURD, NA_real_),
    AGEGR1 = case_when(AGE < 65 ~ "<65", AGE <= 80 ~ "65-80", !is.na(AGE) ~ ">80"),
    AGEGR1N = case_when(AGE < 65 ~ 1, AGE <= 80 ~ 2, !is.na(AGE) ~ 3),
    RACEN = unname(racen[RACE]),
    ITTFL = if_else(!is.na(ARMCD), "Y", "N"),
    SAFFL = if_else(ITTFL == "Y" & !is.na(TRTSDT), "Y", "N"),
    EFFFL = if_else(
      ITTFL == "Y" & USUBJID %in% adas_bl & USUBJID %in% adas_post & USUBJID %in% cibic_post,
      "Y", "N"
    ),
    COMP8FL = if_else(USUBJID %in% attended(8), "Y", "N"),
    COMP16FL = if_else(USUBJID %in% attended(10), "Y", "N"),
    COMP24FL = if_else(USUBJID %in% attended(12), "Y", "N"),
    DTHDT = to_date(DTHDTC),
    BMIBL = WEIGHTBL / (HEIGHTBL / 100)^2,
    BMIBLGR1 = case_when(BMIBL < 25 ~ "<25", BMIBL < 30 ~ "25-<30", !is.na(BMIBL) ~ ">=30"),
    VISIT1DT = to_date(VISIT1DTC),
    RANDDT = to_date(RANDDTC),
    DURDIS = as.numeric(VISIT1DT - DISONSDT + 1) / 30.4375,
    DURDSGR1 = case_when(DURDIS < 12 ~ "<12", !is.na(DURDIS) ~ ">=12"),
    EOTSTT = case_when(EOTDECOD == "COMPLETED" ~ "COMPLETED", !is.na(EOTDECOD) ~ "DISCONTINUED"),
    DCTREAS = if_else(EOTSTT == "DISCONTINUED", EOTDECOD, NA_character_),
    DISCONFL = if_else(EOTSTT == "DISCONTINUED", "Y", NA_character_),
    DSRAEFL = if_else(DCTREAS == "ADVERSE EVENT", "Y", NA_character_),
    EOSSTT = case_when(EOSDECOD == "COMPLETED" ~ "COMPLETED", !is.na(EOSDECOD) ~ "DISCONTINUED"),
    EOSDT = to_date(EOSDTC),
    DCSREAS = if_else(EOSSTT == "DISCONTINUED", EOSDECOD, NA_character_)
  )

adsl <- finalize(adsl, "ADSL", keys = c("STUDYID", "USUBJID"))
