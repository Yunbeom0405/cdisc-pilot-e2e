# Program : setup.R
# Purpose : Packages, paths and shared helpers for the R ADaM programs ({admiral})
# Run from the P1 project root, e.g. source("r/adam/adsl.R")

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(haven)
  library(readxl)
})

sdtm_dir <- "data/derived/sdtm"
out_dir <- "data/derived/adam-r"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

spec_vars <- read_excel("specs/adam-spec.xlsx", sheet = "Variables")
spec_ds <- read_excel("specs/adam-spec.xlsx", sheet = "Datasets")

# read xpt, blank character values as NA
read_sdtm <- function(domain) {
  read_xpt(file.path(sdtm_dir, paste0(domain, ".xpt"))) |> convert_blanks_to_na()
}

read_adam <- function(ds) {
  read_xpt(file.path(out_dir, paste0(ds, ".xpt"))) |> convert_blanks_to_na()
}

# ISO 8601 text -> Date, date part only
to_date <- function(dtc) {
  as.Date(if_else(!is.na(dtc) & nchar(dtc) >= 10, substr(dtc, 1, 10), NA_character_))
}

# CRF visit -> analysis week (safety BDS)
week <- c(`4` = 2, `5` = 4, `7` = 6, `8` = 8, `9` = 12, `10` = 16, `11` = 20, `12` = 24, `13` = 26)
avisitn <- function(visitnum) unname(week[as.character(visitnum)])

# ADSL variables onto analysis records
add_adsl <- function(dat, adsl, vars) {
  derive_vars_merged(dat, dataset_add = adsl, by_vars = exprs(USUBJID), new_vars = vars)
}

# keep/order variables and labels from the spec, check keys, write xpt
finalize <- function(dat, ds, keys) {
  meta <- filter(spec_vars, Dataset == toupper(ds)) |> arrange(Order)
  label <- filter(spec_ds, Dataset == toupper(ds))$Description

  dups <- dat |> count(across(all_of(keys))) |> filter(n > 1)
  if (nrow(dups) > 0) warning("duplicate key in ", ds, ": ", nrow(dups), " key(s)")

  out <- dat |>
    select(all_of(meta$Variable)) |>
    mutate(across(where(is.numeric), as.double)) |>
    arrange(across(all_of(keys)))
  for (i in seq_len(nrow(meta))) attr(out[[meta$Variable[i]]], "label") <- meta$Label[i]
  for (v in names(out)[vapply(out, inherits, logical(1), "Date")]) attr(out[[v]], "format.sas") <- "DATE9"
  attr(out, "label") <- label

  write_xpt(out, file.path(out_dir, paste0(tolower(ds), ".xpt")), version = 5, name = toupper(ds))
  message(toupper(ds), ": ", nrow(out), " rows")
  invisible(out)
}

# efficacy windows by study day (SAP 8.2)
windows <- tribble(
  ~AVISITN, ~AWTARGET, ~AWLO, ~AWHI, ~AWRANGE,
  0, 1, NA, 1, "<=1",
  8, 56, 2, 84, "2-84",
  16, 112, 85, 140, "85-140",
  24, 168, 141, NA, ">=141"
)

add_window <- function(dat, baseline = TRUE) {
  dat |>
    mutate(AVISITN = case_when(
      is.na(ADY) ~ NA_real_,
      ADY <= 1 ~ if (baseline) 0 else NA_real_,
      ADY <= 84 ~ 8,
      ADY <= 140 ~ 16,
      TRUE ~ 24
    )) |>
    left_join(windows, by = "AVISITN") |>
    mutate(
      AVISIT = case_when(AVISITN == 0 ~ "Baseline", !is.na(AVISITN) ~ paste("Week", AVISITN)),
      AWTDIFF = abs(ADY - AWTARGET),
      AWU = if_else(!is.na(AVISITN), "DAYS", NA_character_)
    ) |>
    # one record per window: closest to target, then earlier
    restrict_derivation(
      derivation = derive_var_extreme_flag,
      args = params(
        by_vars = exprs(USUBJID, PARAMCD, AVISITN), order = exprs(AWTDIFF, ADT),
        new_var = ANL01FL, mode = "first"
      ),
      filter = !is.na(AVISITN) & !is.na(AVAL)
    )
}

# LOCF: carry the last windowed post-baseline value into an empty Week 8/16/24 (efficacy population)
add_locf <- function(dat, param) {
  obs <- filter(dat, PARAMCD == param, ANL01FL == "Y", AVISITN > 0, EFFFL == "Y")
  locf <- obs |>
    distinct(USUBJID) |>
    cross_join(tibble(miss = c(8, 16, 24))) |>
    anti_join(obs, by = c("USUBJID", miss = "AVISITN")) |>
    inner_join(obs, by = "USUBJID", relationship = "many-to-many") |>
    filter(AVISITN < miss) |>
    filter_extreme(by_vars = exprs(USUBJID, miss), order = exprs(AVISITN), mode = "last") |>
    select(-AWLO, -AWHI, -AWRANGE) |>
    mutate(AVISITN = miss, AVISIT = paste("Week", AVISITN), DTYPE = "LOCF") |>
    left_join(select(windows, AVISITN, AWLO, AWHI, AWRANGE), by = "AVISITN") |>
    mutate(AWTARGET = AVISITN * 7, AWTDIFF = abs(ADY - AWTARGET)) |>
    select(-miss)
  bind_rows(dat, locf)
}
