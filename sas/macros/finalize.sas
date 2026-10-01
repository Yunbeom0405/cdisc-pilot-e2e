/*******************************************************************************
Program : finalize.sas
Purpose : Shared macro for SDTM and ADaM programs
*******************************************************************************/

/* keep/order variables, trim char lengths, check keys, write dataset and xpt */
%macro finalize(in, out, label, vars=, keys=, lib=sdtm, path=&xpt);
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
  data &lib..&out(label="&label");
    retain &vars;
    length &lens;
    set _fin(keep=&vars);
  run;
  options varlenchk=warn;

  libname _xpt xport "&path/&out..xpt";
  proc copy in=&lib out=_xpt memtype=data;
    select &out;
  run;
  libname _xpt clear;
%mend finalize;
