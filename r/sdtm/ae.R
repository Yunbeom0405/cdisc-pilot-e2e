# Program : ae.R
# Purpose : Create SDTM AE with {sdtm.oak}
# Needs   : DM (run dm.R first)

source("r/sdtm/setup.R")

dm <- read_sdtm("dm")

# drop exact duplicate rows, blank onset = pre-existing condition -> MH
ae_raw <- read_raw("ae") |>
  distinct() |>
  filter(!is.na(ONSET_DATE)) |>
  generate_oak_id_vars(pat_var = "SUBJECT", raw_src = "ae")

ae0 <-
  assign_no_ct(raw_dat = ae_raw, raw_var = "EVENT_CODE", tgt_var = "AESPID") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "DESCRIPTION", tgt_var = "AETERM") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "MEDDRA_LLT", tgt_var = "AELLT") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "MEDDRA_PT", tgt_var = "AEDECOD") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "MEDDRA_HLT", tgt_var = "AEHLT") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "MEDDRA_HLGT", tgt_var = "AEHLGT") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "MEDDRA_SOC", tgt_var = "AEBODSYS") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "MEDDRA_SOC", tgt_var = "AESOC") %>%
  assign_ct(raw_dat = ae_raw, raw_var = "SEVERITY", tgt_var = "AESEV",
    ct_spec = ct_spec, ct_clst = "AESEV") %>%
  assign_ct(raw_dat = ae_raw, raw_var = "RELATIONSHIP", tgt_var = "AEREL",
    ct_spec = ct_spec, ct_clst = "AEREL") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "SERIOUS", tgt_var = "AESER") %>%
  assign_no_ct(raw_dat = ae_raw, raw_var = "SERIOUS_CODES", tgt_var = "scodes") %>%
  assign_datetime(raw_dat = ae_raw, raw_var = "RECORDED_DATE", tgt_var = "AEDTC",
    raw_fmt = "dd mmm y") %>%
  assign_datetime(raw_dat = ae_raw, raw_var = "ONSET_DATE", tgt_var = "AESTDTC",
    raw_fmt = "dd mmm y") %>%
  assign_datetime(raw_dat = ae_raw, raw_var = "STOP_DATE", tgt_var = "AEENDTC",
    raw_fmt = "dd mmm y") %>%
  mutate(across(c(AEDTC, AESTDTC, AEENDTC), as.character))

# seriousness criteria: CRF code listed in SERIOUS_CODES -> 'Y', else 'N'
sflag <- c(AESDTH = 1, AESLIFE = 2, AESDISAB = 3, AESHOSP = 4,
  AESCONG = 5, AESCAN = 6, AESOD = 7, AESMIE = 8)
for (v in names(sflag)) {
  ae0[[v]] <- if_else(str_detect(coalesce(ae0$scodes, ""), paste0("\\b", sflag[v], "\\b")), "Y", "N")
}

ae <- ae0 |>
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "AE",
    USUBJID = paste0("01-", patient_number),
    AETERM = str_to_upper(str_trim(AETERM)),     # P3
    AESER = str_sub(str_to_upper(AESER), 1, 1)   # P2
  ) |>
  left_join(select(dm, USUBJID, RFSTDTC, RFXSTDTC, RFXENDTC), by = "USUBJID") |>
  mutate(
    EPOCH = epoch(AESTDTC, RFXSTDTC, RFXENDTC),
    AESTDY = study_day(AESTDTC, RFSTDTC),
    AEENDY = study_day(AEENDTC, RFSTDTC)
  ) |>
  derive_seq(tgt_var = "AESEQ", rec_vars = c("USUBJID", "AESPID", "AEDTC"))

ae <- finalize(ae, "AE", "Adverse Events", keys = c("STUDYID", "USUBJID", "AESPID", "AEDTC"))
