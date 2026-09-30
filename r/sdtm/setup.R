# Program : setup.R
# Purpose : Packages, paths, raw data import and shared helpers for the R SDTM programs
# Run from the P1 project root, e.g. source("r/sdtm/dm.R")

suppressPackageStartupMessages({
  library(sdtm.oak)
  library(dplyr)
  library(readr)
  library(readxl)
  library(stringr)
  library(tidyr)
  library(haven)
})

raw_dir <- "raw"
out_dir <- "data/derived/sdtm-r"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

spec_vars <- read_excel("specs/sdtm-spec.xlsx", sheet = "Variables")
ct_spec <- read_ct_spec("r/sdtm/ct_spec.csv")

# read csv as all character, blanks as NA
read_raw <- function(file) {
  read_csv(file.path(raw_dir, paste0(file, ".csv")),
    col_types = cols(.default = "c"), na = "")
}

# read an SDTM xpt, blank character values as NA
read_sdtm <- function(domain) {
  read_xpt(file.path(out_dir, paste0(domain, ".xpt"))) |>
    mutate(across(where(is.character), \(x) na_if(x, "")))
}

# DD MON YYYY -> ISO 8601, unknown parts dropped (UN MAY 2013 -> 2013-05)
iso <- function(x) {
  as.character(create_iso8601(x, .format = "dd mmm y", .na = c("UN", "UNK")))
}

# study day, complete dates only
study_day <- function(dtc, ref) {
  ok <- !is.na(dtc) & !is.na(ref) & nchar(dtc) >= 10 & nchar(ref) >= 10
  dy <- as.integer(as.Date(substr(dtc, 1, 10)) - as.Date(substr(ref, 1, 10)))
  if_else(ok, dy + (dy >= 0), NA_integer_)
}

# temporary rule until SE is available
epoch <- function(dtc, rfxst, rfxen) {
  d <- substr(dtc, 1, 10)
  case_when(
    is.na(dtc) | nchar(dtc) < 10 ~ NA_character_,
    is.na(rfxst) | d < rfxst ~ "SCREENING",
    is.na(rfxen) | d <= rfxen ~ "TREATMENT",
    TRUE ~ "FOLLOW-UP"
  )
}

# planned visits, built by python/trial_design.py
tv <- read_xpt("data/derived/sdtm/tv.xpt") |> select(VISITNUM, VISIT, VISITDY)

# visit lookup written by sv.R
read_svmap <- function() readRDS(file.path(out_dir, "svmap.rds"))

# add visit (SV) and reference dates (DM) to raw findings
with_visit <- function(dat) {
  dm <- read_sdtm("dm") |> select(USUBJID, RFSTDTC, RFXSTDTC, RFXENDTC)
  dat |>
    left_join(read_svmap(), by = c("SUBJECT", "FOLDER", "VISIT_DATE")) |>
    left_join(dm, by = "USUBJID")
}

# pre-dose: before the first dose, or first-dose date at the dosing visit
predose <- function(dtc, rfxst, visitnum) {
  d <- substr(dtc, 1, 10)
  coalesce(nchar(dtc) >= 10 & !is.na(rfxst) & (d < rfxst | (d == rfxst & visitnum == 3)), FALSE)
}

# pre-dose records are SCREENING, also on the first-dose date
finding_epoch <- function(dtc, rfxst, rfxen, pre) {
  if_else(pre, "SCREENING", epoch(dtc, rfxst, rfxen))
}

# flag the last pre-dose record with a result, per subject and `by`
lobxfl <- function(dat, by, res, dtc) {
  last <- dat |>
    filter(pre, !is.na(.data[[res]])) |>
    arrange(.data[[dtc]], VISITNUM) |>
    group_by(across(all_of(c("USUBJID", by)))) |>
    slice_tail(n = 1) |>
    pull(row)
  if_else(dat$row %in% last, "Y", NA_character_)
}

# keep/order variables and labels from the spec, check keys, write xpt
finalize <- function(dat, domain, label, keys) {
  meta <- filter(spec_vars, Dataset == toupper(domain)) |> arrange(Order)

  dups <- dat |> count(across(all_of(keys))) |> filter(n > 1)
  if (nrow(dups) > 0) warning("duplicate key in ", domain, ": ", nrow(dups), " key(s)")

  out <- dat |>
    select(all_of(meta$Variable)) |>
    arrange(across(all_of(keys)))
  for (i in seq_len(nrow(meta))) attr(out[[meta$Variable[i]]], "label") <- meta$Label[i]
  attr(out, "label") <- label

  write_xpt(out, file.path(out_dir, paste0(tolower(domain), ".xpt")),
    version = 5, name = toupper(domain))
  invisible(out)
}
