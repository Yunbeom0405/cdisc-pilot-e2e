/*******************************************************************************
Program : adlb.sas
Purpose : Create ADaM ADLBC (chemistry) and ADLBH (hematology)
          Split by LBCAT as in the CDISC Pilot; a single ADLB is also valid per ADaM IG
*******************************************************************************/

%macro adlb(cat, out, label);

%addadsl(sdtm.lb(where=(lbcat = "&cat" and lbstresn ne . and lbtestcd ne 'HBA1CHGB')), lb1,
  STUDYID SITEID TRT01P TRT01PN TRT01A TRT01AN AGE AGEGR1 AGEGR1N RACE RACEN SEX
  SAFFL TRTSDT TRTEDT COMP24FL)

data lb2;
  set lb1(rename=(trt01p=trtp trt01pn=trtpn trt01a=trta trt01an=trtan));
  length paramcd param parcat1 avisit ablfl anrind avalcat1 ontrtfl $200;
  paramcd = lbtestcd;
  if missing(lbstresu) then param = lbtest;
  else param = strip(lbtest) || ' (' || strip(lbstresu) || ')';
  parcat1 = lbcat;
  aval = lbstresn;
  a1lo = lbstnrlo;
  a1hi = lbstnrhi;
  %dt(lbdtc, adt)
  %ady(adt, ady)

  /* lab baseline is Screening 1, Week -2 */
  if visitnum = 1 then do;
    ablfl = 'Y';
    avisit = 'Baseline';
    avisitn = 0;
  end;
  else do;
    avisitn = input(put(visitnum, avisn.), best.);
    if avisitn ne . then avisit = catx(' ', 'Week', avisitn);
  end;
  if 2 <= avisitn <= 24 then ontrtfl = 'Y';

  if a1lo > 0 then r2a1lo = aval / a1lo;
  if a1hi > 0 then r2a1hi = aval / a1hi;

  /* normal range: limits count as abnormal */
  if a1lo ne . or a1hi ne . then do;
    if a1lo ne . and aval <= a1lo then anrind = 'LOW';
    else if a1hi ne . and aval >= a1hi then anrind = 'HIGH';
    else anrind = 'NORMAL';

    if a1lo ne . and aval < 0.5 * a1lo then avalcat1 = 'LOW';
    else if a1hi ne . and aval > 1.5 * a1hi then avalcat1 = 'HIGH';
    else avalcat1 = 'NORMAL';
  end;
  _row = _n_;
run;

proc sort data=lb2;
  by usubjid paramcd;
run;

data bl;
  set lb2(where=(ablfl = 'Y'));
  keep usubjid paramcd base bnrind basecat1;
  base = aval;
  bnrind = anrind;
  basecat1 = avalcat1;
run;

data lb3;
  merge lb2 bl;
  by usubjid paramcd;
  if avisitn > 0 and base ne . then chg = aval - base;
run;

/* one record per visit: latest date, then highest sequence */
proc sort data=lb3;
  by usubjid paramcd avisitn adt lbseq;
run;

data lb3;
  set lb3;
  by usubjid paramcd avisitn;
  length anl01fl $1;
  if avisit ne '' and last.avisitn then anl01fl = 'Y';
run;

/* change from the previous analysed visit larger than half the normal range */
data _prev;
  set lb3(where=(anl01fl = 'Y'));
  by usubjid paramcd;
  length crit1 crit1fl $200;
  _prev = lag(aval);
  if not first.paramcd and a1lo ne . and a1hi ne . then do;
    crit1 = 'Change from previous visit >50% of (ULN-LLN)';
    crit1fl = ifc(abs(aval - _prev) > 0.5 * (a1hi - a1lo), 'Y', 'N');
  end;
  keep _row crit1 crit1fl;
run;

proc sort data=lb3;
  by _row;
run;

data lb3;
  merge lb3 _prev;
  by _row;
run;

%first(lb3, anl02fl, by=usubjid paramcd, order=descending avisitn, key=_row,
  where=anl01fl = 'Y' and 2 <= avisitn <= 24)

data lb3;
  set lb3;
  label
    trtp = 'Planned Treatment'
    trtpn = 'Planned Treatment (N)'
    trta = 'Actual Treatment'
    trtan = 'Actual Treatment (N)'
    paramcd = 'Parameter Code'
    param = 'Parameter'
    adt = 'Analysis Date'
    ady = 'Analysis Relative Day'
    parcat1 = 'Parameter Category 1'
    avisit = 'Analysis Visit'
    avisitn = 'Analysis Visit (N)'
    aval = 'Analysis Value'
    base = 'Baseline Value'
    chg = 'Change from Baseline'
    a1lo = 'Analysis Range 1 Lower Limit'
    a1hi = 'Analysis Range 1 Upper Limit'
    r2a1lo = 'Ratio to Analysis Range 1 Lower Limit'
    r2a1hi = 'Ratio to Analysis Range 1 Upper Limit'
    anrind = 'Analysis Reference Range Indicator'
    bnrind = 'Baseline Reference Range Indicator'
    avalcat1 = 'Analysis Value Category 1'
    basecat1 = 'Baseline Category 1'
    crit1 = 'Analysis Criterion 1'
    crit1fl = 'Criterion 1 Evaluation Result Flag'
    ablfl = 'Baseline Record Flag'
    ontrtfl = 'On Treatment Record Flag'
    anl01fl = 'Analysis Flag 01'
    anl02fl = 'Analysis Flag 02';
run;

%finalize(lb3, &out, &label, lib=adam,
  vars=STUDYID USUBJID SITEID TRTP TRTPN TRTA TRTAN AGE AGEGR1 AGEGR1N RACE RACEN
    SEX SAFFL TRTSDT TRTEDT COMP24FL PARAMCD PARAM VISITNUM
    VISIT ADT ADY PARCAT1 AVISIT AVISITN AVAL BASE CHG A1LO A1HI R2A1LO R2A1HI
    ANRIND BNRIND AVALCAT1 BASECAT1 CRIT1 CRIT1FL ABLFL ONTRTFL ANL01FL ANL02FL LBSEQ,
  keys=STUDYID USUBJID PARAMCD ADT LBSEQ)

%mend adlb;

%adlb(CHEMISTRY, adlbc, Laboratory Chemistry Analysis Dataset)
%adlb(HEMATOLOGY, adlbh, Laboratory Hematology Analysis Dataset)
