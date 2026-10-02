/*******************************************************************************
Program : setup.sas
Purpose : Paths and shared macros for the TLF programs
*******************************************************************************/

%let root = U:\My SAS Files\Portfolio;
%let out = &root/output/tlf/sas;

options validvarname=upcase dlcreatedir nodate nonumber orientation=landscape;
libname adam "&root/data/derived/adam" access=readonly;
libname _out "&out";
libname _out clear;

/* p-value: 3 decimals, <0.001, >0.99 */
%macro pv(p);
  ifc(missing(&p), '', ifc(&p < 0.001, '<0.001', ifc(&p > 0.99, '>0.99', %f(&p, 3))))
%mend pv;

/* treatment columns: 1 Placebo, 2 Low, 3 High, 4 Total */
proc format;
value $trtcol
'Placebo' = '1'
'Xanomeline Low Dose' = '2'
'Xanomeline High Dose' = '3';
run;

/* fixed decimals, half away from zero */
%macro f(x, d);
  ifc(missing(&x), '', strip(put(round(&x, 10 ** -&d), 32.&d)))
%mend f;

/* n (pct%) with pct to &d decimals; plain 0 when n = 0 */
%macro npct(n, den, d=0);
  ifc(&n = 0, '0', cats(&n) || ' (' || %f(&n / &den * 100, &d) || '%)')
%mend npct;

/* column N from ADSL, one macro variable per column: &n1 - &n4 */
%macro bign(where, trt);
  proc sql noprint;
    select count(*) into :n1 trimmed from adam.adsl where &where and &trt = 'Placebo';
    select count(*) into :n2 trimmed from adam.adsl where &where and &trt = 'Xanomeline Low Dose';
    select count(*) into :n3 trimmed from adam.adsl where &where and &trt = 'Xanomeline High Dose';
    select count(*) into :n4 trimmed from adam.adsl where &where;
  quit;
%mend bign;

/* display dataset (ROW LABEL INDENT C1-Cn) -> RTF + CSV for QC */
%macro report(ds, file, title, cols=, heads=, foot1=, foot2=);
  %local i n;
  %let n = %sysfunc(countw(&cols));

  ods listing close;
  ods rtf file="&out/&file..rtf" style=journal bodytitle;
  title1 j=l 'Protocol: CDISCPILOT01' j=r 'Page ^{thispage} of ^{lastpage}';
  title2 "&title";
  footnote1 j=l "&foot1";
  footnote2 j=l "&foot2";
  footnote3 j=l "Source: sas/tlf/&file..sas";
  ods escapechar='^';

  proc report data=&ds nowd split='|' style(report)={width=100%};
    column row indent label &cols;
    define row / order noprint;
    define indent / display noprint;
    define label / display ' ' style(column)={width=35%};
    %do i = 1 %to &n;
      define %scan(&cols, &i) / display "%scan(&heads, &i, #)" style(column)={just=c};
    %end;
    compute label;
      if indent > 0 then call define(_col_, 'style', cats('style={leftmargin=', indent * 12, 'pt}'));
    endcomp;
  run;

  ods rtf close;
  ods listing;
  title;
  footnote;

  proc export data=&ds(keep=row label &cols) outfile="&out/&file..csv" dbms=csv replace;
  run;
%mend report;
