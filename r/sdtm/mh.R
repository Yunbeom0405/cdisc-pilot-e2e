# Program : mh.R
# Purpose : Create SDTM MH
# Needs   : DM (run dm.R first)

source("r/sdtm/setup.R")

dm <- read_sdtm("dm")

# AD onset, historical diagnoses and the pre-existing conditions of the AE log
primary <- read_raw("mh_ad_onset") |>
  transmute(
    SUBJECT, ord = 1,
    MHCAT = "PRIMARY DIAGNOSIS",
    MHTERM = "ALZHEIMER'S DISEASE",
    MHSTDTC = iso(AD_ONSET_DATE),
    MHDTC = iso(VISIT_DATE)
  )

history <- read_raw("mh_history") |>
  transmute(
    SUBJECT, ord = 2,
    MHCAT = "HISTORICAL DIAGNOSIS",
    MHSPID = paste0("H", LINE),
    MHTERM = str_to_upper(str_trim(DIAGNOSIS)),
    MHLLT = MEDDRA_LLT, MHDECOD = MEDDRA_PT, MHHLT = MEDDRA_HLT,
    MHHLGT = MEDDRA_HLGT, MHBODSYS = MEDDRA_SOC,
    MHENDTC = iso(DATE_RECOVERED),
    MHDTC = iso(VISIT_DATE)
  )

preexisting <- read_raw("ae") |>
  distinct() |>
  filter(is.na(ONSET_DATE)) |>
  transmute(
    SUBJECT, ord = 3,
    MHCAT = "SIGNIFICANT PRE-EXISTING CONDITION",
    MHSPID = EVENT_CODE,
    MHTERM = str_to_upper(str_trim(DESCRIPTION)),
    MHLLT = MEDDRA_LLT, MHDECOD = MEDDRA_PT, MHHLT = MEDDRA_HLT,
    MHHLGT = MEDDRA_HLGT, MHBODSYS = MEDDRA_SOC,
    MHSEV = c("MILD", "MODERATE", "SEVERE")[as.integer(SEVERITY)],
    MHDTC = iso(RECORDED_DATE)
  )

mh <- bind_rows(primary, history, preexisting) |>
  mutate(
    USUBJID = paste0("01-", SUBJECT),
    STUDYID = "CDISCPILOT01",
    DOMAIN = "MH",
    VISITNUM = 1,
    VISIT = "SCREENING 1"
  ) |>
  left_join(select(dm, USUBJID, RFSTDTC), by = "USUBJID") |>
  mutate(MHDY = study_day(MHDTC, RFSTDTC)) |>
  derive_seq(tgt_var = "MHSEQ", rec_vars = c("USUBJID", "ord", "MHSPID"))

mh <- finalize(mh, "MH", "Medical History", keys = c("STUDYID", "USUBJID", "MHCAT", "MHSPID"))
