# Program : setup.R
# Purpose : Packages, paths, raw data import and shared helpers for the R SDTM programs
# Run from the P1 project root, e.g. source("r/sdtm/dm.R")

suppressPackageStartupMessages({
  library(sdtm.oak)
  library(dplyr)
  library(readr)
  library(readxl)
  library(stringr)
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

# study day, complete dates only (MT.DY)
study_day <- function(dtc, ref) {
  ok <- !is.na(dtc) & !is.na(ref) & nchar(dtc) >= 10 & nchar(ref) >= 10
  dy <- as.integer(as.Date(substr(dtc, 1, 10)) - as.Date(substr(ref, 1, 10)))
  if_else(ok, dy + (dy >= 0), NA_integer_)
}

# temporary rule until SE is available (MT.EPOCH)
epoch <- function(dtc, rfxst, rfxen) {
  d <- substr(dtc, 1, 10)
  case_when(
    is.na(dtc) | nchar(dtc) < 10 ~ NA_character_,
    is.na(rfxst) | d < rfxst ~ "SCREENING",
    is.na(rfxen) | d <= rfxen ~ "TREATMENT",
    TRUE ~ "FOLLOW-UP"
  )
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
