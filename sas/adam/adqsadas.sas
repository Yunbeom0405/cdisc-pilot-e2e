/*******************************************************************************
Program : adqsadas.sas
Purpose : Create ADaM ADQSADAS (ADAS-Cog 11)
Needs   : ADSL
*******************************************************************************/

/* the 11 items of ADAS-Cog(11) and their maximum scores */
proc format;
invalue maxsc
'ACITM01' = 10
'ACITM02' = 5
'ACITM04' = 5
'ACITM05' = 5
'ACITM06' = 5
'ACITM07' = 8
'ACITM08' = 12
'ACITM11' = 5
'ACITM12' = 5
'ACITM13' = 5
'ACITM14' = 5
other = .;
value $item
'ACITM01' = 'Word Recall Task'
'ACITM02' = 'Naming Objects And Fingers'
'ACITM04' = 'Commands'
'ACITM05' = 'Constructional Praxis'
'ACITM06' = 'Ideational Praxis'
'ACITM07' = 'Orientation'
'ACITM08' = 'Word Recognition'
'ACITM11' = 'Spoken Language Ability'
'ACITM12' = 'Comprehension of Spoken Language'
'ACITM13' = 'Word Finding Difficulty'
'ACITM14' = 'Recall of Test Instructions';
run;

data items;
  set sdtm.qs(where=(qscat = "ALZHEIMER'S DISEASE ASSESSMENT SCALE"));
  if input(qstestcd, maxsc.) ne .;
run;

/* total: prorated to 0-70 if 1-3 items are missing, null if 4 or more */
proc sql;
  create table total as
  select usubjid, visitnum, max(visit) as visit length=200, qsdtc,
    n(qsstresn) as _n, sum(qsstresn) as _sum,
    sum(ifn(qsstresn ne ., input(qstestcd, maxsc.), 0)) as _maxp
  from items
  group by usubjid, visitnum, qsdtc;
quit;

data qs1;
  set total(in=_t) items(where=(qsstresn ne .));
  length paramcd param $200;
  if _t then do;
    paramcd = 'ACTOT';
    param = 'ADAS-Cog(11) Total Score';
    if 11 - _n < 4 then aval = _sum * 70 / _maxp;
  end;
  else do;
    paramcd = qstestcd;
    param = put(qstestcd, $item.);
    aval = qsstresn;
  end;
run;

%addadsl(qs1, qs2,
  STUDYID SITEID SITEGR1 TRT01P TRT01PN AGE AGEGR1 AGEGR1N RACE RACEN SEX ITTFL EFFFL
  COMP24FL TRTSDT TRTEDT)

data qs3;
  set qs2(rename=(trt01p=trtp trt01pn=trtpn));
  %dt(qsdtc, adt)
  %ady(adt, ady)
  %awindow(bl=Y)
  _row = _n_;
run;

%anlwin(qs3)

data qs3;
  set qs3;
  length ablfl $1;
  if avisitn = 0 and anl01fl = 'Y' then ablfl = 'Y';
run;

%locf(qs3, ACTOT)

data qs4;
  set qs3 _locf;
run;

proc sort data=qs4;
  by usubjid paramcd;
run;

data bl;
  set qs4(where=(ablfl = 'Y'));
  keep usubjid paramcd base;
  base = aval;
run;

data adqsadas1;
  merge qs4 bl;
  by usubjid paramcd;
  if avisitn > 0 and base ne . then chg = aval - base;
  if chg ne . and base ne 0 then pchg = chg / base * 100;
  label
    trtp = 'Planned Treatment'
    trtpn = 'Planned Treatment (N)'
    paramcd = 'Parameter Code'
    param = 'Parameter'
    adt = 'Analysis Date'
    ady = 'Analysis Relative Day'
    avisit = 'Analysis Visit'
    avisitn = 'Analysis Visit (N)'
    aval = 'Analysis Value'
    base = 'Baseline Value'
    chg = 'Change from Baseline'
    pchg = 'Percent Change from Baseline'
    ablfl = 'Baseline Record Flag'
    anl01fl = 'Analysis Flag 01'
    dtype = 'Derivation Type'
    awrange = 'Analysis Window Valid Relative Range'
    awtarget = 'Analysis Window Target'
    awtdiff = 'Analysis Window Diff from Target'
    awlo = 'Analysis Window Beginning Timepoint'
    awhi = 'Analysis Window Ending Timepoint'
    awu = 'Analysis Window Unit';
run;

%finalize(adqsadas1, adqsadas, ADAS-Cog Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SITEID SITEGR1 TRTP TRTPN AGE AGEGR1 AGEGR1N RACE RACEN SEX
    ITTFL EFFFL COMP24FL TRTSDT TRTEDT PARAMCD PARAM VISITNUM VISIT ADT ADY AVISIT
    AVISITN AVAL BASE CHG PCHG ABLFL ANL01FL DTYPE AWRANGE AWTARGET AWTDIFF AWLO
    AWHI AWU QSSEQ,
  keys=STUDYID USUBJID PARAMCD AVISITN ADT DTYPE)
