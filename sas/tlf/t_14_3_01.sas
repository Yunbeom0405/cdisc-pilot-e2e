/*******************************************************************************
Program : t_14_3_01.sas
Purpose : Table 14-3.01 ADAS-Cog (11) Change from Baseline to Week 24 - LOCF
*******************************************************************************/

%bign(efffl = 'Y', trt01p)

data eff;
  set adam.adqsadas(where=(paramcd = 'ACTOT' and anl01fl = 'Y' and efffl = 'Y' and avisitn in (0, 24)));
  col = input(put(trtp, $trtcol.), 1.);
run;

/* descriptive statistics: baseline, Week 24, change */
data eff2;
  set eff;
  if avisitn = 0 then do;
    sec = 1;
    x = aval;
    output;
  end;
  else do;
    sec = 2;
    x = aval;
    output;
    sec = 3;
    x = chg;
    output;
  end;
run;

proc means data=eff2 noprint nway;
  class sec col;
  var x;
  output out=_s n=n mean=mean std=sd median=med min=min max=max;
run;

data desc;
  set _s;
  length label $60 val $40;
  ord = 1; label = 'n'; val = cats(n); output;
  ord = 2; label = 'Mean (SD)'; val = cat(%f(mean, 1), ' (', %f(sd, 2), ')'); output;
  ord = 3; label = 'Median (Range)'; val = cat(%f(med, 1), ' (', %f(min, 1), ';', %f(max, 1), ')'); output;
  keep sec ord label col val;
run;

data heads;
  length label $60 val $40;
  col = 1;
  val = '';
  ord = 0;
  do sec = 1 to 3;
    label = choosec(sec, 'Baseline', 'Week 24', 'Change from Baseline');
    output;
  end;
run;

/* ANCOVA: treatment and site group as factors, baseline as covariate */
data w24;
  set eff(where=(avisitn = 24));
run;

ods exclude all;
proc glm data=w24;
  class sitegr1;
  model chg = trtpn sitegr1 base / solution;
  ods output ParameterEstimates=dose;
run;
quit;

/* class order of TRTP: Placebo, Xanomeline High Dose, Xanomeline Low Dose */
proc glm data=w24;
  class trtp sitegr1;
  model chg = trtp sitegr1 base / clparm;
  estimate 'Low - Placebo' trtp -1 0 1;
  estimate 'High - Placebo' trtp -1 1 0;
  estimate 'High - Low' trtp 0 1 -1;
  ods output Estimates=est;
run;
quit;
ods exclude none;

data infer;
  length label $60 val $40;
  sec = 4;
  if _n_ = 1 then do;
    set dose(where=(parameter = 'TRTPN') keep=parameter probt rename=(probt=p_dose));
    ord = 1; label = 'p-value (Dose Response) [1][2]'; col = 2; val = %pv(p_dose); output;
  end;
  set est;
  _c = ifn(parameter = 'Low - Placebo', 2, 3);
  _o = ifn(parameter = 'High - Low', 5, 2);
  ord = _o; label = ifc(_o = 2, 'p-value (Xan - Placebo) [1][3]', 'p-value (Xan High - Xan Low) [1][3]');
  col = _c; val = %pv(probt); output;
  ord = _o + 1; label = 'Diff of LS Means (SE)'; col = _c; val = cat(%f(estimate, 1), ' (', %f(stderr, 2), ')'); output;
  ord = _o + 2; label = '95% CI'; col = _c; val = cat('(', %f(lowercl, 1), ';', %f(uppercl, 1), ')'); output;
  keep sec ord label col val;
run;

data long;
  set heads desc infer;
run;

proc sort data=long;
  by sec ord label col;
run;

proc transpose data=long out=t_14_3_01(drop=_name_) prefix=c;
  by sec ord label;
  id col;
  var val;
run;

data t_14_3_01;
  retain c1 c2 c3;
  set t_14_3_01;
  row = _n_;
  indent = (sec < 4 and ord > 0) or label in ('Diff of LS Means (SE)', '95% CI');
run;

%report(t_14_3_01, t_14_3_01, Table 14-3.01 ADAS-Cog (11) - Change from Baseline to Week 24 - LOCF,
  cols=c1 c2 c3,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3),
  foot1=Population: Efficacy. [1] ANCOVA with treatment and site group as factors and baseline as covariate.,
  foot2=[2] Treatment (dose) as a continuous variable. [3] Treatment as a categorical variable%str(,) no multiplicity adjustment.)
