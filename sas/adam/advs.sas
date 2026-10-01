/*******************************************************************************
Program : advs.sas
Purpose : Create ADaM ADVS
*******************************************************************************/

%addadsl(sdtm.vs(where=(vsstresn ne .)), vs1,
  STUDYID SITEID TRT01P TRT01PN TRT01A TRT01AN AGE AGEGR1 AGEGR1N RACE RACEN SEX
  SAFFL TRTSDT TRTEDT)

data advs1;
  set vs1(rename=(trt01p=trtp trt01pn=trtpn trt01a=trta trt01an=trtan));
  length paramcd param atpt avisit ablfl $200;
  paramcd = vstestcd;
  param = strip(vstest) || ' (' || strip(vsstresu) || ')';
  atpt = vstpt;
  atptn = vstptnum;
  aval = vsstresn;
  %dt(vsdtc, adt)
  %ady(adt, ady)

  /* baseline: Week 0, height at Screening 1 (SAP 9.2) */
  if visitnum = ifn(vstestcd = 'HEIGHT', 1, 3) then ablfl = 'Y';
  if ablfl = 'Y' then do;
    avisit = 'Baseline';
    avisitn = 0;
  end;
  else do;
    avisitn = input(put(visitnum, avisn.), best.);
    if avisitn ne . then avisit = catx(' ', 'Week', avisitn);
  end;
  _row = _n_;
run;

proc sort data=advs1;
  by usubjid paramcd atptn;
run;

data bl;
  set advs1(where=(ablfl = 'Y'));
  keep usubjid paramcd atptn base;
  base = aval;
run;

data advs2;
  merge advs1 bl;
  by usubjid paramcd atptn;
  if avisitn > 0 and base ne . then chg = aval - base;
  if chg ne . and base ne 0 then pchg = chg / base * 100;
run;

/* one record per visit: latest date, then highest sequence */
proc sort data=advs2;
  by usubjid paramcd atptn avisitn adt vsseq;
run;

data advs2;
  set advs2;
  by usubjid paramcd atptn avisitn;
  length anl01fl $1;
  if avisit ne '' and last.avisitn then anl01fl = 'Y';
run;

/* end of treatment: last analysed visit from Week 2 to Week 24 */
%first(advs2, anl02fl, by=usubjid paramcd atptn, order=descending avisitn, key=_row,
  where=anl01fl = 'Y' and 2 <= avisitn <= 24)

data advs2;
  set advs2;
  label
    trtp = 'Planned Treatment'
    trtpn = 'Planned Treatment (N)'
    trta = 'Actual Treatment'
    trtan = 'Actual Treatment (N)'
    paramcd = 'Parameter Code'
    param = 'Parameter'
    adt = 'Analysis Date'
    ady = 'Analysis Relative Day'
    atpt = 'Analysis Timepoint'
    atptn = 'Analysis Timepoint (N)'
    avisit = 'Analysis Visit'
    avisitn = 'Analysis Visit (N)'
    aval = 'Analysis Value'
    base = 'Baseline Value'
    chg = 'Change from Baseline'
    pchg = 'Percent Change from Baseline'
    ablfl = 'Baseline Record Flag'
    anl01fl = 'Analysis Flag 01'
    anl02fl = 'Analysis Flag 02';
run;

%finalize(advs2, advs, Vital Signs Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SITEID TRTP TRTPN TRTA TRTAN AGE AGEGR1 AGEGR1N RACE RACEN
    SEX SAFFL TRTSDT TRTEDT PARAMCD PARAM VISITNUM VISIT ADT ADY ATPT ATPTN AVISIT
    AVISITN AVAL BASE CHG PCHG ABLFL ANL01FL ANL02FL VSSEQ,
  keys=STUDYID USUBJID PARAMCD ATPTN ADT VSSEQ)
