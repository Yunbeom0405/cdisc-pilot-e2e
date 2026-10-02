# Program : lb.R
# Purpose : Create SDTM LB from the central lab transfer
# Needs   : DM, SV (run dm.R and sv.R first)

source("r/sdtm/setup.R")

# vendor test code -> CDISC test (spec sheet LB Test Map)
lb_map <- read_excel("specs/sdtm-spec.xlsx", sheet = "LB Test Map") |>
  select(TEST_CODE = `Vendor TEST_CODE`, LBTESTCD, LBTEST, LBCAT)

# requisition label -> planned visit
req_visit <- c(
  SCRN = 1, BASE = 3, "WK02-1D" = 3.5, WK02 = 4, WK04 = 5, "WK04+1D" = 6, WK06 = 7,
  WK08 = 8, WK12 = 9, WK16 = 10, WK20 = 11, WK24 = 12, WK26 = 13, RETR = 201
)
nrind <- c(N = "NORMAL", L = "LOW", H = "HIGH", A = "ABNORMAL")

# cancelled results have a FINAL replacement
lb <- read_raw("lab_results") |>
  filter(STATUS == "FINAL") |>
  left_join(lb_map, by = "TEST_CODE") |>
  mutate(
    USUBJID = paste0("01-", str_sub(PATIENT_ID, 1, 3), "-", str_sub(PATIENT_ID, 4)),
    d = as.Date(str_sub(COLLECTION_DT, 1, 10)),
    reqvn = unname(req_visit[REQ_VISIT])
  )

svmap <- read_svmap() |> mutate(d = as.Date(SVSTDTC))
planned <- svmap |> distinct(USUBJID, VISITNUM) |> mutate(found = TRUE)

# 1: requisition visit exists in SV; 2: SV visit on the collection date, unscheduled first
sameday <- svmap |>
  arrange(USUBJID, d, !is.na(SVPRESP), VISITNUM) |>
  distinct(USUBJID, d, .keep_all = TRUE) |>
  select(USUBJID, d, vn_day = VISITNUM)

vis <- lb |>
  distinct(USUBJID, REQ_VISIT, reqvn, d) |>
  left_join(planned, by = join_by(USUBJID, reqvn == VISITNUM)) |>
  left_join(sameday, by = c("USUBJID", "d")) |>
  mutate(VISITNUM = coalesce(if_else(found, reqvn, NA_real_), vn_day))

# 3: new unscheduled visit, previous planned visit + .1, .2
before <- svmap |> filter(!is.na(SVPRESP)) |> select(USUBJID, d_sv = d, VISITNUM)

new <- vis |>
  filter(is.na(VISITNUM)) |>
  distinct(USUBJID, d) |>
  left_join(before, by = join_by(USUBJID, closest(d > d_sv))) |>
  group_by(USUBJID, d) |>
  summarise(base = coalesce(max(VISITNUM), 0), .groups = "drop") |>
  arrange(USUBJID, base, d) |>
  group_by(USUBJID, base) |>
  mutate(new_num = round(base + row_number() / 10, 2)) |>
  ungroup() |>
  select(USUBJID, d, new_num)

stopifnot(nrow(inner_join(new, planned, by = join_by(USUBJID, new_num == VISITNUM))) == 0)

vis <- vis |>
  left_join(new, by = c("USUBJID", "d")) |>
  mutate(VISITNUM = coalesce(VISITNUM, new_num)) |>
  select(USUBJID, REQ_VISIT, d, VISITNUM)

visit_names <- svmap |> distinct(USUBJID, VISITNUM, VISIT, VISITDY)

lb <- lb |>
  left_join(vis, by = c("USUBJID", "REQ_VISIT", "d")) |>
  left_join(visit_names, by = c("USUBJID", "VISITNUM")) |>
  mutate(VISIT = coalesce(VISIT, paste("UNSCHEDULED", VISITNUM))) |>
  left_join(select(read_sdtm("dm"), USUBJID, RFSTDTC, RFXSTDTC, RFXENDTC), by = "USUBJID")

lb <- lb |>
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "LB",
    LBREFID = ACCESSION,
    LBORRES = RESULT,
    LBORRESU = UNITS,
    LBORNRLO = REF_LOW,
    LBORNRHI = REF_HIGH,
    LBSTRESC = RESULT_SI,
    LBSTRESN = suppressWarnings(as.numeric(RESULT_SI)),   # '<0.2' and text results stay null
    LBSTRESU = case_when(
      LBTESTCD == "HBA1CHGB" ~ UNITS_SI,   # hemoglobin fraction, not a volume ratio
      UNITS_SI == "GI/L" ~ "10^9/L",
      UNITS_SI == "TI/L" ~ "10^12/L",
      UNITS_SI == "1" ~ "L/L",
      TRUE ~ UNITS_SI
    ),
    LBSTNRLO = as.numeric(REF_LOW_SI),
    LBSTNRHI = as.numeric(REF_HIGH_SI),
    LBNRIND = unname(nrind[ABN_FLAG]),
    LBDTC = COLLECTION_DT,
    pre = predose(LBDTC, RFXSTDTC, VISITNUM),
    EPOCH = finding_epoch(LBDTC, RFXSTDTC, RFXENDTC, pre),
    LBDY = study_day(LBDTC, RFSTDTC),
    row = row_number()
  )

lb$LBLOBXFL <- lobxfl(lb, "LBTESTCD", "LBORRES", "LBDTC")

lb <- lb |>
  derive_seq(tgt_var = "LBSEQ", rec_vars = c("USUBJID", "LBCAT", "LBTESTCD", "LBDTC"))

lb <- finalize(lb, "LB", "Laboratory Test Results",
  keys = c("STUDYID", "USUBJID", "LBCAT", "LBTESTCD", "LBDTC"))
