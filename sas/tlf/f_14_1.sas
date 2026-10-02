/*******************************************************************************
Program : f_14_1.sas
Purpose : Figure 14-1 Kaplan-Meier: Time to First Dermatologic Event
          (+ statistics table f_14_1_stats for QC)
*******************************************************************************/

data tte;
  set adam.adtte(where=(paramcd = 'TTDE' and saffl = 'Y'));
  col = input(put(trta, $trtcol.), 1.);
run;

proc format;
value col
1 = 'Placebo'
2 = 'Xanomeline Low Dose'
3 = 'Xanomeline High Dose';
run;

ods listing close;
ods rtf file="&out/f_14_1.rtf" style=journal bodytitle;
ods graphics on / width=9in height=5.5in;
title1 j=l 'Protocol: CDISCPILOT01';
title2 'Figure 14-1 Kaplan-Meier: Time to First Dermatologic Event by Treatment Group';
footnote1 j=l 'Population: Safety. Event: first treatment emergent dermatologic adverse event (CSR Table 12-2).';
footnote2 j=l 'Censored at end of study. Source: sas/tlf/f_14_1.sas';

ods output Quartiles=q ProductLimitEstimates=pl CensoredSummary=cs;
proc lifetest data=tte plots=survival(atrisk=0 to 210 by 30) timelist=30 60 90 120 150 180 reduceout;
  time aval * cnsr(1);
  strata col;
  format col col.;
run;

ods rtf close;
ods graphics off;
ods listing;
title;
footnote;

/* statistics for QC: N, events, censored, median (95% CI), KM estimates */
data stats;
  length label $60 val $40;
  set cs(where=(col ne .) in=a) q(where=(percent = 50) in=b) pl(in=c);
  if a then do;
    ord = 1; label = 'N'; val = cats(total); output;
    ord = 2; label = 'Events'; val = cats(failed); output;
    ord = 3; label = 'Censored'; val = cats(censored); output;
  end;
  else if b then do;
    ord = 4; label = 'Median (95% CI)';
    val = cat(%f(estimate, 1), ' (', coalescec(%f(lowerlimit, 1), 'NE'), ';', coalescec(%f(upperlimit, 1), 'NE'), ')');
    if estimate = . then val = 'NE';
    output;
  end;
  else do;
    ord = 4 + timelist / 30; label = cat('Event-free at Day ', timelist); val = %f(survival, 3);
    output;
  end;
  keep col ord label val;
run;

proc sort data=stats;
  by ord label col;
run;

proc transpose data=stats out=f_14_1_stats(drop=_name_) prefix=c;
  by ord label;
  id col;
  var val;
run;

data f_14_1_stats;
  set f_14_1_stats;
  row = _n_;
  indent = 0;
run;

%bign(saffl = 'Y', trt01a)

%report(f_14_1_stats, f_14_1_stats, Figure 14-1 Statistics: Time to First Dermatologic Event,
  cols=c1 c2 c3,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3),
  foot1=Population: Safety. Kaplan-Meier estimates%str(,) 95% CI with log-log transformation.,
  foot2=NE: not estimable.)
