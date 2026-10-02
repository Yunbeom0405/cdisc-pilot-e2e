# Program : compare.R
# Purpose : Compare R TLF cells (output/tlf/r) with SAS TLF cells (output/tlf/sas), cell by cell
# Output  : output/validation/tlf-r-vs-sas.txt

library(readr)
library(diffdf)

tlfs <- c("t_14_1_01", "t_14_2_01", "t_14_3_01", "t_14_5_01", "t_a3", "t_lb_shift", "f_14_1_stats", "f_a8_stats")

report <- "output/validation/tlf-r-vs-sas.txt"
if (file.exists(report)) file.remove(report)

read_cells <- function(dir, name) {
  read_csv(file.path(dir, paste0(name, ".csv")), col_types = cols(.default = "c"), na = character()) |>
    setNames(toupper(names(read_csv(file.path(dir, paste0(name, ".csv")), n_max = 0, show_col_types = FALSE)))) |>
    lapply(trimws) |>
    as.data.frame()
}

for (t in tlfs) {
  sas_file <- file.path("output/tlf/sas", paste0(t, ".csv"))
  if (!file.exists(sas_file)) {
    message(t, ": no SAS file, skipped")
    next
  }
  sas <- read_cells("output/tlf/sas", t)
  r <- read_cells("output/tlf/r", t)
  cat("\n=====", toupper(t), "=====\n", file = report, append = TRUE)
  res <- diffdf(sas, r, keys = "ROW", suppress_warnings = TRUE)
  cat(if (length(res) == 0) "No issues found\n" else capture.output(print(res)),
    sep = "\n", file = report, append = TRUE)
  message(t, ": ", if (length(res) == 0) "match" else "DIFFERENCES - see report")
}
