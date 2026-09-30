# Program : compare.R
# Purpose : Compare R SDTM (data/derived/sdtm-r) with SAS SDTM (data/derived/sdtm) using {diffdf}
# Output  : output/validation/sdtm-r-vs-sas.txt

library(haven)
library(diffdf)

keys <- list(
  dm     = "USUBJID",
  ae     = c("USUBJID", "AESEQ"),
  ds     = c("USUBJID", "DSSEQ"),
  suppds = c("USUBJID", "IDVARVAL", "QNAM"),
  relrec = c("USUBJID", "RDOMAIN", "IDVARVAL"),
  sv     = c("USUBJID", "VISIT"),
  ex     = c("USUBJID", "EXSEQ"),
  mh     = c("USUBJID", "MHSEQ"),
  vs     = c("USUBJID", "VSSEQ"),
  qs     = c("USUBJID", "QSSEQ"),
  lb     = c("USUBJID", "LBSEQ")
)

report <- "output/validation/sdtm-r-vs-sas.txt"
dir.create(dirname(report), showWarnings = FALSE, recursive = TRUE)
if (file.exists(report)) file.remove(report)

for (d in names(keys)) {
  sas_file <- file.path("data/derived/sdtm", paste0(d, ".xpt"))
  if (!file.exists(sas_file)) {
    message(d, ": no SAS file, skipped")
    next
  }
  sas <- read_xpt(sas_file)
  r   <- read_xpt(file.path("data/derived/sdtm-r", paste0(d, ".xpt")))
  cat("\n=====", toupper(d), "=====\n", file = report, append = TRUE)
  res <- diffdf(sas, r, keys = keys[[d]], suppress_warnings = TRUE)
  cat(if (length(res) == 0) "No issues found\n" else capture.output(print(res)),
    sep = "\n", file = report, append = TRUE)
  message(d, ": ", if (length(res) == 0) "match" else "DIFFERENCES - see report")
}
