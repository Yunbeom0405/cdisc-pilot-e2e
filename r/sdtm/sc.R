# Program : sc.R
# Purpose : Create SDTM SC
# Needs   : DM (run dm.R first)

source("r/sdtm/setup.R")

dm <- read_sdtm("dm")

sc <- read_raw("sc_su") |>
  filter(!is.na(EDU_YEARS)) |>
  transmute(
    USUBJID = paste0("01-", SUBJECT),
    STUDYID = "CDISCPILOT01",
    DOMAIN = "SC",
    SCSEQ = 1,
    SCTESTCD = "EDUYRNUM",
    SCTEST = "Number of Years of Education",
    # free text such as '12 yrs' keeps the number only
    SCORRES = str_trim(EDU_YEARS),
    SCORRESU = "YEARS",
    SCSTRESN = as.numeric(str_extract(SCORRES, "\\d+")),
    SCSTRESC = as.character(SCSTRESN),
    SCSTRESU = "YEARS",
    VISITNUM = 1,
    VISIT = "SCREENING 1",
    SCDTC = iso(VISIT_DATE)
  ) |>
  left_join(select(dm, USUBJID, RFSTDTC, RFXSTDTC, RFXENDTC), by = "USUBJID") |>
  mutate(
    EPOCH = epoch(SCDTC, RFXSTDTC, RFXENDTC),
    SCDY = study_day(SCDTC, RFSTDTC)
  )

sc <- finalize(sc, "SC", "Subject Characteristics", keys = c("STUDYID", "USUBJID", "SCTESTCD"))
