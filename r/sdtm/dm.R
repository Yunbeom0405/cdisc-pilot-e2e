# Program : dm.R
# Purpose : Create SDTM DM with {sdtm.oak}

source("r/sdtm/setup.R")

dm_raw <- read_raw("dm") |>
  generate_oak_id_vars(pat_var = "SUBJECT", raw_src = "dm")

irt <- read_raw("irt_randomization") |>
  mutate(SUBJECT = paste(SITE_ID, SUBJECT_ID, sep = "-"))
ex <- read_raw("ex_dosage")
ds_sum <- read_raw("ds_summary")

# per-subject values from other raw files
ex_subj <- ex |>
  group_by(SUBJECT) |>
  summarise(
    RFXSTDTC = iso(first(VISIT_DATE[FOLDER == "V3"])),
    RFXENDTC = iso(first(na.omit(LAST_DOSE_DATE))),
    any25 = any(PATCH25_PER_DAY == "1")
  )

# RFPENDTC: latest contact date (MT.RFPENDTC)
contact <- bind_rows(
  read_raw("visits") |> transmute(SUBJECT, dtc = iso(VISIT_DATE)),
  ds_sum |> transmute(SUBJECT, dtc = iso(VISIT_DATE)),
  read_raw("ae") |> transmute(SUBJECT, dtc = iso(RECORDED_DATE)),
  irt |> transmute(SUBJECT, dtc = substr(SCREEN_FAIL_DATETIME, 1, 10))
) |>
  filter(!is.na(dtc)) |>
  group_by(SUBJECT) |>
  summarise(RFPENDTC = max(dtc))

# collected variables, mapped from dm.csv
dm0 <-
  assign_no_ct(raw_dat = dm_raw, raw_var = "SITE", tgt_var = "SITEID") %>%
  assign_no_ct(raw_dat = dm_raw, raw_var = "SEX", tgt_var = "SEX") %>%
  assign_ct(raw_dat = dm_raw, raw_var = "ORIGIN", tgt_var = "RACE",
    ct_spec = ct_spec, ct_clst = "RACE") %>%
  assign_ct(raw_dat = dm_raw, raw_var = "ORIGIN", tgt_var = "ETHNIC",
    ct_spec = ct_spec, ct_clst = "ETHNIC") %>%
  assign_datetime(raw_dat = dm_raw, raw_var = "CONSENT_DATE", tgt_var = "RFICDTC",
    raw_fmt = "dd mmm y") %>%
  assign_datetime(raw_dat = dm_raw, raw_var = "BIRTH_DATE", tgt_var = "BRTHDTC",
    raw_fmt = "dd mmm y") %>%
  assign_datetime(raw_dat = dm_raw, raw_var = "VISIT_DATE", tgt_var = "DMDTC",
    raw_fmt = "dd mmm y") %>%
  mutate(across(c(RFICDTC, BRTHDTC, DMDTC), as.character))

dm <- dm0 |>
  mutate(
    SUBJECT = patient_number,
    STUDYID = "CDISCPILOT01",
    DOMAIN = "DM",
    USUBJID = paste0("01-", SUBJECT),
    SUBJID = str_extract(SUBJECT, "[^-]+$"),
    COUNTRY = "USA",
    AGEU = "YEARS"
  ) |>
  left_join(select(irt, SUBJECT, SUBJECT_STATUS, TREATMENT_ARM), by = "SUBJECT") |>
  left_join(ex_subj, by = "SUBJECT") |>
  left_join(transmute(ds_sum, SUBJECT, RFENDTC = iso(VISIT_DATE), DTHDTC = iso(DEATH_DATE)),
    by = "SUBJECT") |>
  left_join(contact, by = "SUBJECT") |>
  mutate(
    RFSTDTC = RFXSTDTC,
    DTHFL = if_else(!is.na(DTHDTC), "Y", NA_character_),

    # AGE: partial birth date imputed to 01 JUL for the calculation only
    brth = as.Date(case_when(
      nchar(BRTHDTC) == 4 ~ paste0(BRTHDTC, "-07-01"),
      nchar(BRTHDTC) == 7 ~ paste0(BRTHDTC, "-01"),
      TRUE ~ BRTHDTC
    )),
    ic = as.Date(RFICDTC),
    AGE = as.integer(format(ic, "%Y")) - as.integer(format(brth, "%Y")) -
      (format(ic, "%m%d") < format(brth, "%m%d")),

    # arms (MT.ARMCD, MT.ACTARM, MT.ARMNRS)
    screen_fail = SUBJECT_STATUS == "Screen Failed",
    ARM = if_else(screen_fail, NA_character_, TREATMENT_ARM),
    ARMCD = ct_map(ARM, ct_spec = ct_spec, ct_clst = "ARMCD"),
    ACTARM = case_when(
      is.na(any25) ~ NA_character_,
      ARMCD == "Xan_Hi" & !any25 ~ "Xanomeline Low Dose",
      TRUE ~ ARM
    ),
    ACTARMCD = ct_map(ACTARM, ct_spec = ct_spec, ct_clst = "ARMCD"),
    ARMNRS = case_when(
      screen_fail ~ "SCREEN FAILURE",
      is.na(any25) ~ "ASSIGNED, NOT TREATED"
    ),

    DMDY = study_day(DMDTC, RFSTDTC)
  )

dm <- finalize(dm, "DM", "Demographics", keys = c("STUDYID", "USUBJID"))
