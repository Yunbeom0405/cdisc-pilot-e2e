# Program : compare.R
# Purpose : Compare R ADaM (data/derived/adam-r) with SAS ADaM (data/derived/adam) using {diffdf}
# Output  : output/validation/adam-r-vs-sas.txt

library(haven)
library(diffdf)

keys <- list(
  adsl     = "USUBJID",
  adae     = c("USUBJID", "AESEQ"),
  admh     = c("USUBJID", "MHSEQ"),
  advs     = c("USUBJID", "PARAMCD", "ATPTN", "ADT", "VSSEQ"),
  adlbc    = c("USUBJID", "PARAMCD", "ADT", "LBSEQ"),
  adlbh    = c("USUBJID", "PARAMCD", "ADT", "LBSEQ"),
  adlbhy   = c("USUBJID", "PARAMCD", "AVISITN"),
  adtte    = c("USUBJID", "PARAMCD"),
  adqsadas = c("USUBJID", "PARAMCD", "AVISITN", "ADT", "DTYPE"),
  adqscibc = c("USUBJID", "PARAMCD", "AVISITN", "ADT", "DTYPE")
)

report <- "output/validation/adam-r-vs-sas.txt"
dir.create(dirname(report), showWarnings = FALSE, recursive = TRUE)
if (file.exists(report)) file.remove(report)

for (d in names(keys)) {
  r_file <- file.path("data/derived/adam-r", paste0(d, ".xpt"))
  if (!file.exists(r_file)) {
    message(d, ": no R file, skipped")
    next
  }
  sas <- read_xpt(file.path("data/derived/adam", paste0(d, ".xpt")))
  r   <- read_xpt(r_file)
  cat("\n=====", toupper(d), "=====\n", file = report, append = TRUE)
  res <- diffdf(sas, r, keys = keys[[d]], suppress_warnings = TRUE, tolerance = 1e-8)
  cat(if (length(res) == 0) "No issues found\n" else capture.output(print(res)),
    sep = "\n", file = report, append = TRUE)
  message(d, ": ", if (length(res) == 0) "match" else "DIFFERENCES - see report")
}
