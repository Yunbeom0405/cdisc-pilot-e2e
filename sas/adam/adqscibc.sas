/*******************************************************************************
Program : adqscibc.sas
Purpose : Create ADaM ADQSCIBC (CIBIC+)
Needs   : ADSL
*******************************************************************************/

data qs1;
  set sdtm.qs(where=(qscat = 'ADCS-CGIC' and qsstresn ne .));
  length paramcd param avalc $200;
  paramcd = 'CIBIC';
  param = 'CIBIC+ Score';
  aval = qsstresn;
  avalc = qsorres;
run;

%addadsl(qs1, qs2,
  STUDYID SITEID SITEGR1 TRT01P TRT01PN AGE AGEGR1 AGEGR1N RACE RACEN SEX ITTFL EFFFL
  COMP24FL TRTSDT TRTEDT)

/* no baseline: CIBIC+ rates change from baseline */
data qs3;
  set qs2(rename=(trt01p=trtp trt01pn=trtpn));
  %dt(qsdtc, adt)
  %ady(adt, ady)
  %awindow(bl=N)
  _row = _n_;
run;

%anlwin(qs3)
%locf(qs3, CIBIC)

data adqscibc1;
  set qs3 _locf;
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
    avalc = 'Analysis Value (C)'
    anl01fl = 'Analysis Flag 01'
    dtype = 'Derivation Type'
    awrange = 'Analysis Window Valid Relative Range'
    awtarget = 'Analysis Window Target'
    awtdiff = 'Analysis Window Diff from Target'
    awlo = 'Analysis Window Beginning Timepoint'
    awhi = 'Analysis Window Ending Timepoint'
    awu = 'Analysis Window Unit';
run;

%finalize(adqscibc1, adqscibc, CIBIC+ Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SITEID SITEGR1 TRTP TRTPN AGE AGEGR1 AGEGR1N RACE RACEN SEX
    ITTFL EFFFL COMP24FL TRTSDT TRTEDT PARAMCD PARAM VISITNUM VISIT ADT ADY AVISIT
    AVISITN AVAL AVALC ANL01FL DTYPE AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU,
  keys=STUDYID USUBJID PARAMCD AVISITN ADT DTYPE)
