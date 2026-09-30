# Program : sv.R
# Purpose : Create SDTM SV and the raw visit -> VISITNUM lookup (svmap.rds) for VS, QS and LB
# Needs   : DM (run dm.R first)

source("r/sdtm/setup.R")

dm <- read_sdtm("dm")

visits <- read_raw("visits") |>
  mutate(
    USUBJID = paste0("01-", SUBJECT),
    dt = as.Date(iso(VISIT_DATE)),
    uns = FOLDER == "UNS",
    tel = str_detect(FOLDER, "^V\\d+T$"),
    num = as.numeric(str_extract(FOLDER, "\\d+")),
    VISITNUM = case_when(
      FOLDER == "ET" ~ as.numeric(VISIT_NO),
      FOLDER == "V3E" ~ 3.5,
      tel ~ num + 0.5,
      !uns ~ num
    )
  )

# unscheduled visit: previous planned visit + .1, .2
visits <- visits |>
  arrange(USUBJID, dt, uns, VISITNUM) |>
  group_by(USUBJID) |>
  mutate(base = if_else(uns, NA_real_, VISITNUM), grp = cumsum(!uns)) |>
  fill(base) |>
  group_by(USUBJID, grp) |>
  mutate(VISITNUM = if_else(uns, round(coalesce(base, 0) + cumsum(uns) / 10, 2), VISITNUM)) |>
  ungroup()

stopifnot(!anyDuplicated(visits[c("USUBJID", "VISITNUM")]))

sv <- visits |>
  left_join(tv, by = "VISITNUM") |>
  left_join(select(dm, USUBJID, RFSTDTC, RFXSTDTC, RFXENDTC), by = "USUBJID") |>
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "SV",
    VISIT = if_else(uns, paste("UNSCHEDULED", VISITNUM), VISIT),
    VISITDY = if_else(uns, NA_real_, VISITDY),
    SVPRESP = if_else(uns, NA_character_, "Y"),
    SVCNTMOD = if_else(tel, "TELEPHONE CALL", "IN PERSON"),
    SVSTDTC = iso(VISIT_DATE),
    SVENDTC = SVSTDTC,
    EPOCH = epoch(SVSTDTC, RFXSTDTC, RFXENDTC),
    SVSTDY = study_day(SVSTDTC, RFSTDTC),
    SVENDY = study_day(SVENDTC, RFSTDTC)
  )

svmap <- select(sv, SUBJECT, FOLDER, VISIT_DATE, USUBJID, VISITNUM, VISIT, VISITDY, SVPRESP, SVSTDTC)
saveRDS(svmap, file.path(out_dir, "svmap.rds"))

sv <- finalize(sv, "SV", "Subject Visits", keys = c("STUDYID", "USUBJID", "VISITNUM"))
