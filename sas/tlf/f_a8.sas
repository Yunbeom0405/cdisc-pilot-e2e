/*******************************************************************************
Program : f_a8.sas
Purpose : Figure A8 eDISH, peak ALT vs peak bilirubin (x ULN)
          (+ statistics table f_a8_stats for QC)
*******************************************************************************/

proc format;
value col
1 = 'Placebo'
2 = 'Xanomeline Low Dose'
3 = 'Xanomeline High Dose';
run;

/* peak on-treatment value as multiple of the upper limit, per subject */
proc sql;
  create table pk as
  select usubjid, paramcd, input(put(trta, $trtcol.), 1.) as col, max(aval / a1hi) as x
  from adam.adlbc
  where ontrtfl = 'Y' and saffl = 'Y' and paramcd in ('ALT', 'BILI') and not missing(aval) and not missing(a1hi)
  group by usubjid, paramcd, calculated col;

  create table ed as
  select a.usubjid, a.col, a.x as alt, b.x as bili
  from pk(where=(paramcd = 'ALT')) a inner join pk(where=(paramcd = 'BILI')) b
    on a.usubjid = b.usubjid;

  create table st as
  select col, count(*) as n, sum(alt >= 3) as a, sum(bili >= 2) as b, sum(alt >= 3 and bili >= 2) as ab
  from ed group by col;
quit;

ods listing close;
ods rtf file="&out/f_a8.rtf" style=journal bodytitle;
ods graphics on / width=9in height=6in;
title1 j=l 'Protocol: CDISCPILOT01';
title2 'Figure A8 eDISH: Peak ALT vs Peak Total Bilirubin (x ULN) by Treatment Group';
footnote1 j=l 'Population: Safety. One point per subject, peak on-treatment value. Reference lines: ALT 3 x ULN, bilirubin 2 x ULN.';
footnote2 j=l 'Source: sas/tlf/f_a8.sas';

proc sgplot data=ed;
  scatter x=alt y=bili / group=col markerattrs=(symbol=circlefilled size=7);
  refline 3 / axis=x lineattrs=(pattern=shortdash);
  refline 2 / axis=y lineattrs=(pattern=shortdash);
  xaxis type=log logbase=10 label='Peak ALT (x ULN)';
  yaxis type=log logbase=10 label='Peak total bilirubin (x ULN)';
  format col col.;
  keylegend / title=' ';
run;

ods rtf close;
ods graphics off;
ods listing;
title;
footnote;

data st2;
  set st;
  length label $200 val $40;
  ord = 1; label = 'N (ALT and bilirubin measured)'; val = cats(n); output;
  ord = 2; label = 'ALT >= 3 x ULN'; val = %npct(a, n, d=1); output;
  ord = 3; label = 'Bilirubin >= 2 x ULN'; val = %npct(b, n, d=1); output;
  ord = 4; label = 'ALT >= 3 x ULN and bilirubin >= 2 x ULN'; val = %npct(ab, n, d=1); output;
  keep col ord label val;
run;

proc sort data=st2;
  by ord label col;
run;

proc transpose data=st2 out=f_a8_stats(drop=_name_) prefix=c;
  by ord label;
  id col;
  var val;
run;

data f_a8_stats;
  set f_a8_stats;
  row = _n_;
  indent = 0;
run;

%bign(trt01a, where=%str(saffl = 'Y'))

%report(f_a8_stats, f_a8_stats, Figure A8 Statistics: Peak ALT and Bilirubin,
  cols=c1 c2 c3,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3),
  foot1=Population: Safety. Peak on-treatment value as multiple of the upper limit of normal (ULN) at the same record.,
  foot2=Cells: subjects (percent of N with both measurements).)
