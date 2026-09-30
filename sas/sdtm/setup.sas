/*******************************************************************************
Program : setup.sas
Purpose : Paths, raw data import and shared macros for the SDTM programs
*******************************************************************************/

%let root = U:\My SAS Files\Portfolio;
%let raw = &root/raw;
%let xpt = &root/data/derived/sdtm;

options validvarname=upcase dlcreatedir compress=yes;
libname sdtm "&xpt";

/* read csv as all character, variable names from the header row */
%macro readcsv(file);
  %local vars;
  data _null_;
    infile "&raw/&file..csv" obs=1 lrecl=32767;
    input;
    call symputx('vars', translate(compress(_infile_, '0D'x), ' ', ','));
  run;

  data raw_&file;
    infile "&raw/&file..csv" dsd firstobs=2 truncover lrecl=32767;
    input @;
    _infile_ = compress(_infile_, '0D'x);
    length &vars $200;
    input &vars;
  run;
%mend readcsv;

%readcsv(dm)
%readcsv(irt_randomization)
%readcsv(ex_dosage)
%readcsv(final_dose)
%readcsv(ds_summary)
%readcsv(visits)
%readcsv(ae)
%readcsv(mh_ad_onset)
%readcsv(mh_history)
%readcsv(vs_wt_ht)
%readcsv(vs_bp)
%readcsv(vs_temp)
%readcsv(qs_mmse)
%readcsv(qs_adas)
%readcsv(qs_cibic)
%readcsv(lab_results)

/* trial visits, built by python/trial_design.py */
libname _tv xport "&xpt/tv.xpt";
data tv;
  set _tv.tv(keep=visitnum visitdy);
run;
libname _tv clear;

/* planned visit names */
proc format;
  value visit
    1 = 'SCREENING 1'
    2 = 'SCREENING 2'
    3 = 'BASELINE'
    3.5 = 'AMBUL ECG PLACEMENT'
    4 = 'WEEK 2'
    5 = 'WEEK 4'
    6 = 'AMBUL ECG REMOVAL'
    7 = 'WEEK 6'
    8 = 'WEEK 8'
    8.5 = 'WEEK 10 (T)'
    9 = 'WEEK 12'
    9.5 = 'WEEK 14 (T)'
    10 = 'WEEK 16'
    10.5 = 'WEEK 18 (T)'
    11 = 'WEEK 20'
    11.5 = 'WEEK 22 (T)'
    12 = 'WEEK 24'
    13 = 'WEEK 26'
    201 = 'RETRIEVAL'
    501 = 'AE FOLLOW-UP';
run;

/* DD MON YYYY -> ISO 8601, unknown parts dropped (UN MAY 2013 -> 2013-05) */
%macro iso(in, out);
  if scan(&in, 2, ' ') = 'UNK' then &out = scan(&in, 3, ' ');
  else if scan(&in, 1, ' ') = 'UN' then
    &out = put(input(cats('01', scan(&in, 2, ' '), scan(&in, 3, ' ')), date9.), yymmd7.);
  else if not missing(&in) then &out = put(input(compress(&in), date9.), e8601da.);
%mend iso;

/* study day, complete dates only */
%macro dy(dtc, out);
  if length(&dtc) >= 10 and length(rfstdtc) >= 10 then do;
    &out = input(substr(&dtc, 1, 10), e8601da.) - input(rfstdtc, e8601da.);
    &out = &out + (&out >= 0);
  end;
%mend dy;

/* temporary rule until SE is available */
/* pre-dose: before the first dose, or first-dose date at the dosing visit */
%macro predose(dtc);
  _pre = length(&dtc) >= 10 and not missing(rfxstdtc) and
    (substr(&dtc, 1, 10) < rfxstdtc or (substr(&dtc, 1, 10) = rfxstdtc and visitnum = 3));
%mend predose;

/* pre-dose records are SCREENING, also on the first-dose date */
%macro fepoch(dtc);
  if _pre then epoch = 'SCREENING';
  else %epoch(&dtc)
%mend fepoch;

/* flag the last pre-dose record with a result, per subject and &by */
%macro lobxfl(in, flag, by=, res=, dtc=);
  proc sort data=&in(where=(_pre and not missing(&res))) out=_lobx(keep=_row usubjid &by &dtc visitnum);
    by usubjid &by &dtc visitnum;
  run;

  data _lobx;
    set _lobx;
    by usubjid &by;
    if last.%scan(&by, -1);
    keep _row;
  run;

  proc sort data=_lobx;
    by _row;
  run;

  proc sort data=&in;
    by _row;
  run;

  data &in;
    merge &in _lobx(in=_hit);
    by _row;
    length &flag $200;
    if _hit then &flag = 'Y';
  run;
%mend lobxfl;

%macro epoch(dtc);
  if length(&dtc) >= 10 then do;
    if missing(rfxstdtc) or substr(&dtc, 1, 10) < rfxstdtc then epoch = 'SCREENING';
    else if missing(rfxendtc) or substr(&dtc, 1, 10) <= rfxendtc then epoch = 'TREATMENT';
    else epoch = 'FOLLOW-UP';
  end;
%mend epoch;

/* keep/order variables, trim char lengths, check keys, write dataset and xpt */
%macro finalize(in, out, label, vars=, keys=);
  %local cvars n i sel into lens last;
  %let last = %scan(&keys, -1);

  proc sql noprint;
    select name into :cvars separated by ' '
    from dictionary.columns
    where libname = 'WORK' and memname = "%upcase(&in)" and type = 'char'
      and findw("%upcase(&vars)", strip(name)) > 0;
  quit;
  %let n = &sqlobs;

  %do i = 1 %to &n;
    %if &i > 1 %then %do;
      %let sel = &sel,;
      %let into = &into,;
    %end;
    %let sel = &sel max(length(%scan(&cvars, &i)));
    %let into = &into :len&i trimmed;
  %end;

  proc sql noprint;
    select &sel into &into from &in;
  quit;

  %do i = 1 %to &n;
    %let lens = &lens %scan(&cvars, &i) $&&len&i;
  %end;

  proc sort data=&in out=_fin;
    by &keys;
  run;

  data _null_;
    set _fin;
    by &keys;
    if not (first.&last and last.&last) then
      put 'WARN' "ING: duplicate key in &out: " usubjid=;
  run;

  options varlenchk=nowarn;
  data sdtm.&out(label="&label");
    retain &vars;
    length &lens;
    set _fin(keep=&vars);
  run;
  options varlenchk=warn;

  libname _xpt xport "&xpt/&out..xpt";
  proc copy in=sdtm out=_xpt memtype=data;
    select &out;
  run;
  libname _xpt clear;
%mend finalize;
