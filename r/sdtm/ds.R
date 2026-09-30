# Program : ds.R
# Purpose : Create SDTM DS, SUPPDS and RELREC with {sdtm.oak}
# Needs   : DM (run dm.R first)

source("r/sdtm/setup.R")

dm <- read_sdtm("dm")

dsterm_txt <- c(
  "1" = "PROTOCOL COMPLETED",
  "3" = "ADVERSE EVENT",
  "4" = "DEATH",
  "8" = "LACK OF EFFICACY, PATIENT/CAREGIVER PERCEPTION",
  "9" = "LACK OF EFFICACY, PHYSICIAN PERCEPTION",
  "11" = "UNABLE TO CONTACT PATIENT (LOST TO FOLLOW-UP)",
  "13" = "PERSONAL CONFLICT OR OTHER PATIENT/CAREGIVER DECISION",
  "14" = "PROTOCOL ENTRY CRITERIA NOT MET",
  "18" = "SPONSOR DECISION (STUDY OR PATIENT DISCONTINUED BY THE SPONSOR)",
  "22" = "PHYSICIAN DECISION",
  "243" = "PROTOCOL VIOLATION"
)

visit_name <- c(
  "1" = "SCREENING 1", "2" = "SCREENING 2", "3" = "BASELINE", "4" = "WEEK 2",
  "5" = "WEEK 4", "6" = "AMBUL ECG REMOVAL", "7" = "WEEK 6", "8" = "WEEK 8",
  "9" = "WEEK 12", "10" = "WEEK 16", "11" = "WEEK 20", "12" = "WEEK 24",
  "13" = "WEEK 26", "201" = "RETRIEVAL"
)

dm_raw <- read_raw("dm") |>
  generate_oak_id_vars(pat_var = "SUBJECT", raw_src = "dm")
irt_raw <- read_raw("irt_randomization") |>
  mutate(SUBJECT = paste(SITE_ID, SUBJECT_ID, sep = "-")) |>
  generate_oak_id_vars(pat_var = "SUBJECT", raw_src = "irt_randomization")
ds_raw <- read_raw("ds_summary") |>
  generate_oak_id_vars(pat_var = "SUBJECT", raw_src = "ds_summary")

# (1) informed consent - all subjects
ds_ic <-
  hardcode_no_ct(raw_dat = dm_raw, raw_var = "CONSENT_DATE", tgt_var = "DSTERM",
    tgt_val = "INFORMED CONSENT OBTAINED") %>%
  assign_datetime(raw_dat = dm_raw, raw_var = "CONSENT_DATE", tgt_var = "DSSTDTC",
    raw_fmt = "dd mmm y") %>%
  mutate(DSCAT = "PROTOCOL MILESTONE")

# (2) randomized, (3) screen failure - from IxRS
ds_rand <-
  hardcode_no_ct(raw_dat = filter(irt_raw, SUBJECT_STATUS == "Randomized"),
    raw_var = "RANDOMIZATION_DATETIME", tgt_var = "DSTERM", tgt_val = "RANDOMIZED") %>%
  assign_no_ct(raw_dat = irt_raw, raw_var = "RANDOMIZATION_DATETIME", tgt_var = "DSSTDTC") %>%
  mutate(DSCAT = "PROTOCOL MILESTONE")

ds_sf <-
  hardcode_no_ct(raw_dat = filter(irt_raw, SUBJECT_STATUS == "Screen Failed"),
    raw_var = "SCREEN_FAIL_DATETIME", tgt_var = "DSTERM", tgt_val = "SCREEN FAILURE") %>%
  assign_no_ct(raw_dat = irt_raw, raw_var = "SCREEN_FAIL_DATETIME", tgt_var = "DSSTDTC") %>%
  mutate(DSCAT = "DISPOSITION EVENT", DSSCAT = "STUDY PARTICIPATION")

# (4) study treatment - one per randomized subject
ds_trt <-
  assign_ct(raw_dat = ds_raw, raw_var = "REASON", tgt_var = "DSDECOD",
    ct_spec = ct_spec, ct_clst = "NCOMPLT") %>%
  assign_datetime(raw_dat = ds_raw, raw_var = "VISIT_DATE", tgt_var = "DSSTDTC",
    raw_fmt = "dd mmm y") %>%
  left_join(select(ds_raw, all_of(oak_id_vars()), REASON, REASON_SPECIFY, VISIT_NO,
    AE_CODE, ENTRY_CRITERION), by = oak_id_vars()) |>
  mutate(
    DSCAT = "DISPOSITION EVENT",
    DSSCAT = "STUDY TREATMENT",
    DSTERM = coalesce(REASON_SPECIFY, dsterm_txt[REASON]),
    VISITNUM = as.numeric(VISIT_NO)
  )

# (5) study participation: COMPLETED if seen at V201 after the treatment record
v201 <- read_raw("visits") |>
  filter(FOLDER == "V201") |>
  transmute(patient_number = SUBJECT, v201 = iso(VISIT_DATE))

ds_part <- ds_trt |>
  mutate(DSSTDTC = as.character(DSSTDTC)) |>
  left_join(v201, by = "patient_number") |>
  mutate(
    DSSCAT = "STUDY PARTICIPATION",
    retr = !is.na(v201) & v201 > DSSTDTC,
    DSTERM = if_else(retr, "COMPLETED RETRIEVAL VISIT", DSTERM),
    DSDECOD = if_else(retr, "COMPLETED", DSDECOD),
    VISITNUM = if_else(retr, 201, VISITNUM),
    DSSTDTC = if_else(retr, v201, DSSTDTC),
    AE_CODE = NA_character_,
    ENTRY_CRITERION = NA_character_
  )

ds <- bind_rows(
  lapply(list(ds_ic, ds_rand, ds_sf, ds_trt, ds_part), \(d) mutate(d, DSSTDTC = as.character(DSSTDTC)))
) |>
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "DS",
    USUBJID = paste0("01-", patient_number),
    DSDECOD = coalesce(DSDECOD, DSTERM),
    VISIT = unname(visit_name[as.character(VISITNUM)])
  ) |>
  left_join(select(dm, USUBJID, RFSTDTC, RFXSTDTC, RFXENDTC), by = "USUBJID") |>
  mutate(
    EPOCH = if_else(DSCAT == "PROTOCOL MILESTONE", "SCREENING",
      epoch(DSSTDTC, RFXSTDTC, RFXENDTC)),
    DSSTDY = study_day(DSSTDTC, RFSTDTC),
    # fixed record order (MT.DSSEQ)
    ds_ord = case_when(
      DSDECOD == "INFORMED CONSENT OBTAINED" ~ 1L,
      DSDECOD == "RANDOMIZED" ~ 2L,
      DSSCAT == "STUDY TREATMENT" ~ 3L,
      DSSCAT == "STUDY PARTICIPATION" ~ 4L
    )
  ) |>
  derive_seq(tgt_var = "DSSEQ", rec_vars = c("USUBJID", "ds_ord"))

ds_out <- finalize(ds, "DS", "Disposition",
  keys = c("STUDYID", "USUBJID", "DSSEQ"))

# SUPPDS: entry criterion not met (REASON = 14)
suppds <- ds |>
  filter(DSSCAT == "STUDY TREATMENT", !is.na(ENTRY_CRITERION)) |>
  transmute(
    STUDYID, RDOMAIN = "DS", USUBJID,
    IDVAR = "DSSEQ", IDVARVAL = as.character(DSSEQ),
    QNAM = "ENTCRIT", QLABEL = "Protocol Entry Criteria Not Met",
    QVAL = ENTRY_CRITERION, QORIG = "CRF", QEVAL = NA_character_
  )
finalize(suppds, "SUPPDS", "Supplemental Qualifiers for DS",
  keys = c("STUDYID", "RDOMAIN", "USUBJID", "IDVAR", "IDVARVAL", "QNAM"))

# RELREC: DS discontinuation due to AE <-> AE
rel <- ds |> filter(DSSCAT == "STUDY TREATMENT", !is.na(AE_CODE))
relrec <- bind_rows(
  transmute(rel, STUDYID, RDOMAIN = "DS", USUBJID, IDVAR = "DSSEQ", IDVARVAL = as.character(DSSEQ)),
  transmute(rel, STUDYID, RDOMAIN = "AE", USUBJID, IDVAR = "AESPID", IDVARVAL = AE_CODE)
) |>
  mutate(RELTYPE = NA_character_, RELID = "DSAE")
finalize(relrec, "RELREC", "Related Records",
  keys = c("STUDYID", "USUBJID", "RDOMAIN", "IDVAR", "IDVARVAL", "RELID"))
