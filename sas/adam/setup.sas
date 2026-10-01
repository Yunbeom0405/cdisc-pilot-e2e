/*******************************************************************************
Program : setup.sas
Purpose : Paths and shared macros for the ADaM programs
*******************************************************************************/

%let root = U:\My SAS Files\Portfolio;
%let xpt = &root/data/derived/adam;

options validvarname=upcase dlcreatedir compress=yes;
libname sdtm "&root/data/derived/sdtm" access=readonly;
libname adam "&xpt";

%include "&root/sas/macros/finalize.sas";

/* CRF visit -> analysis week (safety BDS) */
proc format;
value avisn
4 = '2'
5 = '4'
7 = '6'
8 = '8'
9 = '12'
10 = '16'
11 = '20'
12 = '24'
13 = '26'
other = ' ';
run;

/* ISO 8601 date text -> SAS date, date part only */
%macro dt(dtc, out);
  if length(&dtc) >= 10 then &out = input(substr(&dtc, 1, 10), e8601da.);
  format &out date9.;
%mend dt;

/* analysis day relative to first dose, no day 0 */
%macro ady(dt, out);
  if &dt ne . and trtsdt ne . then &out = &dt - trtsdt + (&dt >= trtsdt);
%mend ady;

/* ADSL variables onto analysis records */
%macro addadsl(in, out, vars);
  proc sort data=&in out=_add;
    by usubjid;
  run;

  data &out;
    merge _add(in=_in) adam.adsl(keep=usubjid &vars);
    by usubjid;
    if _in;
  run;
%mend addadsl;

/* flag the first record of each &by group, in &order, among records where &where */
%macro first(data, flag, by=, order=, key=, where=1);
  proc sort data=&data(where=(&where))
    out=_f(keep=&key &by %sysfunc(prxchange(s/descending//i, -1, &order)));
    by &by &order;
  run;

  data _f;
    set _f;
    by &by;
    length &flag $1;
    if first.%scan(&by, -1);
    &flag = 'Y';
    keep &key &flag;
  run;

  proc sort data=_f;
    by &key;
  run;

  proc sort data=&data;
    by &key;
  run;

  data &data;
    merge &data _f;
    by &key;
  run;
%mend first;

/* efficacy windows by study day (SAP 8.2); baseline window only if &bl = Y */
%macro awindow(bl=Y);
  length avisit awrange awu $200;
  if ady = . then;
  else if ady <= 1 then do;
    if "&bl" = 'Y' then do;
      avisitn = 0;
      awtarget = 1;
      awhi = 1;
      awrange = '<=1';
    end;
  end;
  else if ady <= 84 then do;
    avisitn = 8;
    awtarget = 56;
    awlo = 2;
    awhi = 84;
    awrange = '2-84';
  end;
  else if ady <= 140 then do;
    avisitn = 16;
    awtarget = 112;
    awlo = 85;
    awhi = 140;
    awrange = '85-140';
  end;
  else do;
    avisitn = 24;
    awtarget = 168;
    awlo = 141;
    awrange = '>=141';
  end;
  if avisitn = 0 then avisit = 'Baseline';
  else if avisitn ne . then avisit = catx(' ', 'Week', avisitn);
  if avisitn ne . then do;
    awtdiff = abs(ady - awtarget);
    awu = 'DAYS';
  end;
%mend awindow;

/* one record per subject, parameter and window: closest to target, then earlier */
%macro anlwin(data);
  %first(&data, anl01fl, by=usubjid paramcd avisitn, order=awtdiff adt, key=_row,
    where=avisitn ne . and aval ne .)
%mend anlwin;

/* LOCF: carry the last windowed post-baseline value into an empty Week 8/16/24 */
%macro locf(data, param);
  data _obs;
    set &data(where=(paramcd = "&param" and anl01fl = 'Y' and avisitn > 0 and efffl = 'Y'));
  run;

  data _skel;
    set adam.adsl(keep=usubjid efffl where=(efffl = 'Y'));
    do avisitn = 8, 16, 24;
      output;
    end;
    keep usubjid avisitn;
  run;

  /* latest earlier observed window for each empty window */
  proc sql;
    create table _locf as
    select o.*, s.avisitn as _miss
    from _skel as s
    inner join _obs as o on s.usubjid = o.usubjid and o.avisitn < s.avisitn
    where not exists (select 1 from _obs as x where x.usubjid = s.usubjid and x.avisitn = s.avisitn)
    group by s.usubjid, s.avisitn
    having o.avisitn = max(o.avisitn);
  quit;

  data _locf;
    set _locf;
    length dtype $200;
    avisitn = _miss;
    avisit = catx(' ', 'Week', avisitn);
    awtarget = avisitn * 7;
    awtdiff = abs(ady - awtarget);
    if avisitn = 16 then do;
      awlo = 85;
      awhi = 140;
      awrange = '85-140';
    end;
    else if avisitn = 24 then do;
      awlo = 141;
      awhi = .;
      awrange = '>=141';
    end;
    dtype = 'LOCF';
    drop _miss;
  run;
%mend locf;
