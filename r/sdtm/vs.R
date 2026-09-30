# Program : vs.R
# Purpose : Create SDTM VS
# Needs   : DM, SV (run dm.R and sv.R first)

source("r/sdtm/setup.R")

vs_test <- c(
  DIABP = "Diastolic Blood Pressure", HEIGHT = "Height", PULSE = "Pulse Rate",
  SYSBP = "Systolic Blood Pressure", TEMP = "Temperature", WEIGHT = "Weight"
)
std_unit <- c(WEIGHT = "kg", HEIGHT = "cm", TEMP = "C", SYSBP = "mmHg", DIABP = "mmHg", PULSE = "beats/min")
temp_site <- c(PO = "ORAL CAVITY", E = "EAR", R = "RECTUM", A = "AXILLA")

timepoints <- tribble(
  ~TIMING_CODE, ~VSTPT, ~VSELTM,
  "815", "AFTER LYING DOWN FOR 5 MINUTES", "PT5M",
  "816", "AFTER STANDING FOR 1 MINUTE", "PT1M",
  "817", "AFTER STANDING FOR 3 MINUTES", "PT3M"
)

# one record per test from the three CRF forms
wt_ht <- read_raw("vs_wt_ht")

weight <- wt_ht |>
  transmute(
    SUBJECT, FOLDER, VISIT_DATE, VSTESTCD = "WEIGHT", VSORRES = WEIGHT,
    VSORRESU = if_else(WEIGHT_UNIT == "lb", "LB", WEIGHT_UNIT)
  )

height <- wt_ht |>
  filter(!is.na(HEIGHT)) |>
  transmute(SUBJECT, FOLDER, VISIT_DATE, VSTESTCD = "HEIGHT", VSORRES = HEIGHT, VSORRESU = HEIGHT_UNIT)

bp <- read_raw("vs_bp") |>
  left_join(timepoints, by = "TIMING_CODE") |>
  mutate(
    VSTPTNUM = as.numeric(TIMING_CODE),
    VSPOS = if_else(POSITION == "SU", "SUPINE", "STANDING"),
    VSTPTREF = paste("PATIENT", VSPOS)
  ) |>
  pivot_longer(c(HEART_RATE, SYSTOLIC, DIASTOLIC), names_to = "test", values_to = "VSORRES") |>
  mutate(
    VSTESTCD = c(HEART_RATE = "PULSE", SYSTOLIC = "SYSBP", DIASTOLIC = "DIABP")[test],
    VSORRESU = if_else(VSTESTCD == "PULSE", "beats/min", "mmHg")
  )

temp <- read_raw("vs_temp") |>
  mutate(
    VSTESTCD = "TEMP", VSORRES = TEMPERATURE, VSORRESU = TEMP_UNIT,
    VSLOC = unname(temp_site[TEMP_METHOD])
  )

vs <- bind_rows(weight, height, bp, temp) |>
  with_visit() |>
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "VS",
    VSTEST = unname(vs_test[VSTESTCD]),
    VSSTAT = if_else(is.na(VSORRES), "NOT DONE", NA_character_)
  )

# standard unit per test; no unit collected, no standard value
vs <- vs |>
  mutate(
    std = case_when(
      VSORRESU == "LB" ~ as.numeric(VSORRES) * 0.45359237,
      VSORRESU == "in" ~ as.numeric(VSORRES) * 2.54,
      VSORRESU == "F" ~ (as.numeric(VSORRES) - 32) * 5 / 9,
      .default = as.numeric(VSORRES)
    ),
    VSSTRESN = if_else(is.na(VSORRESU), NA_real_, round(std, 2)),
    VSSTRESC = as.character(VSSTRESN),
    VSSTRESU = if_else(is.na(VSSTRESN), NA_character_, unname(std_unit[VSTESTCD])),
    VSDTC = iso(VISIT_DATE),
    pre = predose(VSDTC, RFXSTDTC, VISITNUM),
    EPOCH = finding_epoch(VSDTC, RFXSTDTC, RFXENDTC, pre),
    VSDY = study_day(VSDTC, RFSTDTC),
    row = row_number()
  )

vs$VSLOBXFL <- lobxfl(vs, c("VSTESTCD", "VSTPTNUM"), "VSORRES", "VSDTC")

vs <- vs |>
  derive_seq(tgt_var = "VSSEQ", rec_vars = c("USUBJID", "VSTESTCD", "VSDTC", "VISITNUM", "VSTPTNUM"))

vs <- finalize(vs, "VS", "Vital Signs",
  keys = c("STUDYID", "USUBJID", "VSTESTCD", "VISITNUM", "VSTPTNUM"))
