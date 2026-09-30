# Program : qs.R
# Purpose : Create SDTM QS (MMSE, ADAS-Cog, CIBIC+ as ADCS-CGIC)
# Needs   : DM, SV (run dm.R and sv.R first)

source("r/sdtm/setup.R")

# question names from the spec
qs_names <- read_excel("specs/sdtm-spec.xlsx", sheet = "Codelists") |>
  filter(ID %in% c("QSTESTCD", "ACGC01TC")) |>
  transmute(QSTESTCD = Term, QSTEST = `Decoded Value`)

mmse_scat <- c("ORIENTATION", "ORIENTATION", "REGISTRATION", "ATTENTION AND CALCULATION", "RECALL", "LANGUAGE")
cibic_text <- c(
  "MARKED IMPROVEMENT", "MODERATE IMPROVEMENT", "MINIMAL IMPROVEMENT", "NO CHANGE",
  "MINIMAL WORSENING", "MODERATE WORSENING", "MARKED WORSENING"
)

# one record per item
mmse <- read_raw("qs_mmse") |>
  pivot_longer(starts_with("ITEM"), names_to = "item", values_to = "QSORRES") |>
  mutate(
    n = as.integer(str_extract(item, "\\d+")),
    QSCAT = "MINI-MENTAL STATE",
    QSTESTCD = sprintf("MMITM%02d", n),
    QSSCAT = mmse_scat[n]
  )

adas <- read_raw("qs_adas") |>
  pivot_longer(starts_with("ITEM"), names_to = "item", values_to = "QSORRES") |>
  mutate(
    n = as.integer(str_extract(item, "\\d+")),
    QSCAT = "ALZHEIMER'S DISEASE ASSESSMENT SCALE",
    QSTESTCD = sprintf("ACITM%02d", n),
    QSORRESU = if_else(n == 10 & !is.na(QSORRES), "s", NA_character_)
  )

cibic <- read_raw("qs_cibic") |>
  mutate(
    QSCAT = "ADCS-CGIC",
    QSTESTCD = "ACGC0101",
    QSORRES = cibic_text[as.integer(CIBIC)]
  )

items <- bind_rows(mmse, adas, cibic)

# page not done: one QSALL record
page <- c("SUBJECT", "FOLDER", "VISIT_DATE", "QSCAT")
qs <- bind_rows(
  filter(items, is.na(NOT_OBTAINED)),
  items |> filter(!is.na(NOT_OBTAINED)) |> distinct(across(all_of(page))) |> mutate(QSTESTCD = "QSALL")
) |>
  left_join(qs_names, by = "QSTESTCD") |>
  with_visit() |>
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN = "QS",
    QSSTRESC = if_else(QSCAT == "ADCS-CGIC", CIBIC, QSORRES),
    QSSTRESN = as.numeric(QSSTRESC),
    QSSTRESU = QSORRESU,
    QSSTAT = if_else(is.na(QSORRES), "NOT DONE", NA_character_),
    QSDTC = iso(VISIT_DATE),
    pre = predose(QSDTC, RFXSTDTC, VISITNUM),
    EPOCH = finding_epoch(QSDTC, RFXSTDTC, RFXENDTC, pre),
    QSDY = study_day(QSDTC, RFSTDTC),
    row = row_number()
  )

qs$QSLOBXFL <- lobxfl(qs, c("QSCAT", "QSTESTCD"), "QSORRES", "QSDTC")

qs <- qs |>
  derive_seq(tgt_var = "QSSEQ", rec_vars = c("USUBJID", "QSCAT", "QSTESTCD", "VISITNUM"))

qs <- finalize(qs, "QS", "Questionnaires",
  keys = c("STUDYID", "USUBJID", "QSCAT", "QSTESTCD", "VISITNUM"))
