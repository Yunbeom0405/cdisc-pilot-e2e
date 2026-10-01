/*******************************************************************************
Program : adtte.sas
Purpose : Create ADaM ADTTE
Needs   : ADSL, ADAE
*******************************************************************************/

/* first treatment-emergent dermatologic event */
proc sort data=adam.adae(where=(cq01nam ne '' and trtemfl = 'Y')) out=derm(keep=usubjid astdt aeseq);
  by usubjid astdt aeseq;
run;

data derm;
  set derm;
  by usubjid;
  if first.usubjid;
run;

data tte1;
  merge adam.adsl(in=_s where=(saffl = 'Y')) derm;
  by usubjid;
  if _s;
  length paramcd param evntdesc srcdom srcvar trta $200;
  trta = trt01a;
  trtan = trt01an;
  startdt = trtsdt;

  paramcd = 'TTDE';
  param = 'Time to First Dermatologic Event (Days)';
  srcdom = 'ADAE';
  srcvar = 'ASTDT';
  if astdt ne . then do;
    adt = astdt;
    cnsr = 0;
    evntdesc = 'DERMATOLOGIC EVENT';
    srcseq = aeseq;
  end;
  else do;
    adt = eosdt;
    cnsr = 1;
    evntdesc = 'END OF STUDY';
    srcdom = 'ADSL';
    srcvar = 'EOSDT';
  end;
  aval = adt - startdt + 1;
  output;

  paramcd = 'TTDISC';
  param = 'Time to Treatment Discontinuation (Days)';
  adt = trtedt;
  cnsr = ifn(eotstt = 'DISCONTINUED', 0, 1);
  evntdesc = ifc(cnsr = 0, 'TREATMENT DISCONTINUED', 'TREATMENT COMPLETED');
  srcdom = 'ADSL';
  srcvar = 'TRTEDT';
  srcseq = .;
  aval = adt - startdt + 1;
  output;

  format startdt adt date9.;
  label
    trta = 'Actual Treatment'
    trtan = 'Actual Treatment (N)'
    paramcd = 'Parameter Code'
    param = 'Parameter'
    startdt = 'Time to Event Origin Date for Subject'
    adt = 'Analysis Date'
    aval = 'Analysis Value'
    cnsr = 'Censor'
    evntdesc = 'Event or Censoring Description'
    srcdom = 'Source Data'
    srcvar = 'Source Variable'
    srcseq = 'Source Sequence Number';
run;

%finalize(tte1, adtte, Time to Event Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SITEID TRTA TRTAN AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL
    TRTSDT TRTEDT PARAMCD PARAM STARTDT ADT AVAL CNSR EVNTDESC SRCDOM SRCVAR SRCSEQ,
  keys=STUDYID USUBJID PARAMCD)
