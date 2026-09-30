# Program : ex.R
# Purpose : Create SDTM EX
# Needs   : DM (run dm.R first)

source("r/sdtm/setup.R")

dm <- read_sdtm("dm")

arm <- read_raw("irt_randomization") |>
  transmute(SUBJECT = paste(SITE_ID, SUBJECT_ID, sep = "-"), TREATMENT_ARM)
final_dose <- read_raw("final_dose") |>
  transmute(SUBJECT, final = iso(FINAL_DOSE_DATE))

ex <- read_raw("ex_dosage") |>
  left_join(arm, by = "SUBJECT") |>
  left_join(final_dose, by = "SUBJECT") |>
  mutate(
    USUBJID = paste0("01-", SUBJECT),
    EXSTDTC = iso(VISIT_DATE),
    VISITNUM = as.numeric(str_remove(FOLDER, "V"))
  ) |>
  left_join(select(dm, USUBJID, RFSTDTC, RFXSTDTC, RFXENDTC), by = "USUBJID") |>
  left_join(tv, by = "VISITNUM") |>
  arrange(USUBJID, EXSTDTC) |>
  group_by(USUBJID) |>
  mutate(next_start = lead(EXSTDTC)) |>
  ungroup()

# an interval ends the day before the next one; the last one on the final dose date
ex <- ex |>
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "EX",
    EXTRT = if_else(TREATMENT_ARM == "Placebo", "PLACEBO", "XANOMELINE"),
    EXDOSE = as.numeric(PATCH25_PER_DAY) * 27 * (TREATMENT_ARM == "Xanomeline High Dose") +
      as.numeric(PATCH50_PER_DAY) * 54 * (TREATMENT_ARM != "Placebo"),
    EXDOSU = "mg",
    EXDOSFRM = "PATCH",
    EXDOSFRQ = "QD",
    EXROUTE = "TRANSDERMAL",
    EXENDTC = if_else(is.na(next_start), final, as.character(as.Date(next_start) - 1)),
    EPOCH = epoch(EXSTDTC, RFXSTDTC, RFXENDTC),
    EXSTDY = study_day(EXSTDTC, RFSTDTC),
    EXENDY = study_day(EXENDTC, RFSTDTC)
  ) |>
  derive_seq(tgt_var = "EXSEQ", rec_vars = c("USUBJID", "EXSTDTC"))

ex <- finalize(ex, "EX", "Exposure", keys = c("STUDYID", "USUBJID", "EXTRT", "EXSTDTC"))
