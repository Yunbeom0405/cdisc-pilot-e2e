# Program : setup.R
# Purpose : Packages, paths and shared helpers for the R TLF programs ({rtables})
# Run from the P1 project root, e.g. source("r/tlf/t_14_1_01.R")

suppressPackageStartupMessages({
  library(rtables)
  library(dplyr)
  library(tidyr)
  library(haven)
  library(readr)
})

adam_dir <- "data/derived/adam"
out_dir <- "output/tlf/r"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

trt_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")

read_adam <- function(ds) {
  read_xpt(file.path(adam_dir, paste0(ds, ".xpt"))) |>
    mutate(across(where(is.character), \(x) na_if(x, "")))
}

# round half away from zero, as SAS does
sas_round <- function(x, d) sign(x) * floor(abs(x) * 10^d + 0.5 + 1e-9) / 10^d + 0

# fixed decimals; blank when missing
f <- function(x, d) {
  x <- as.numeric(x)
  ifelse(is.na(x), "", formatC(sas_round(x, d), format = "f", digits = d))
}

# n (pct%), plain 0 when n = 0
npct <- function(n, den, d = 0) if_else(n == 0, "0", paste0(n, " (", f(n / den * 100, d), "%)"))

# p-value: 3 decimals, <0.001, >0.99
pv <- function(p) case_when(is.na(p) ~ "", p < 0.001 ~ "<0.001", p > 0.99 ~ ">0.99", TRUE ~ f(p, 3))

# rtables table -> display data (ROW, LABEL, C1..Cn) for QC, plus text output
save_tlf <- function(tbl, name, title, foot = character()) {
  cells <- get_formatted_cells(tbl)
  colnames(cells) <- paste0("C", seq_len(ncol(cells)))
  out <- tibble(ROW = seq_len(nrow(cells)), LABEL = make_row_df(tbl)$label) |>
    bind_cols(as_tibble(cells))
  write_csv(out, file.path(out_dir, paste0(name, ".csv")), na = "")

  main_title(tbl) <- title
  main_footer(tbl) <- c(foot, paste0("Source: r/tlf/", name, ".R"))
  export_as_txt(tbl, file = file.path(out_dir, paste0(name, ".txt")), paginate = FALSE)
  message(name, ": ", nrow(out), " rows")
  invisible(out)
}

# display data frame (ROW, LABEL, INDENT, C1..Cn) -> csv + text via rtables
save_df <- function(df, name, title, heads, foot = character(), src = name) {
  write_csv(select(df, -INDENT), file.path(out_dir, paste0(name, ".csv")), na = "")
  body <- select(df, starts_with("C"))
  rows <- lapply(seq_len(nrow(df)), \(i) {
    r <- rrowl(df$LABEL[i], as.list(unlist(body[i, ])), format = "xx", indent = df$INDENT[i])
    obj_name(r) <- as.character(df$ROW[i])
    r
  })
  tbl <- rtable(header = heads, .lst = rows)
  main_title(tbl) <- title
  main_footer(tbl) <- c(foot, paste0("Source: r/tlf/", src, ".R"))
  export_as_txt(tbl, file = file.path(out_dir, paste0(name, ".txt")), paginate = FALSE)
  message(name, ": ", nrow(df), " rows")
  invisible(df)
}
