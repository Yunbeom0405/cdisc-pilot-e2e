/*******************************************************************************
Program : adlbhy.sas
Purpose : Create ADaM ADLBHY (modified Hy's law)
Needs   : ADLBC
*******************************************************************************/

/* per visit: any ALT/AST and BILI above 1.5 x ULN */
proc sql;
  create table hy0 as
  select usubjid, avisitn, max(avisit) as avisit length=200, max(adt) as adt format=date9.,
    max(ablfl) as ablfl length=1, max(ontrtfl) as ontrtfl length=1,
    sum(paramcd in ('ALT', 'AST')) as _nt, max(paramcd in ('ALT', 'AST') and r2a1hi > 1.5) as _t,
    sum(paramcd = 'BILI') as _nb, max(paramcd = 'BILI' and r2a1hi > 1.5) as _b
  from adam.adlbc
  where paramcd in ('ALT', 'AST', 'BILI') and anl01fl = 'Y'
  group by usubjid, avisitn;
quit;

data hy1;
  set hy0;
  length paramcd param $200;
  if _nt then do;
    paramcd = 'TRANSHY';
    param = 'ALT or AST >1.5 x ULN';
    aval = _t;
    output;
  end;
  if _nb then do;
    paramcd = 'BILIHY';
    param = 'Bilirubin >1.5 x ULN';
    aval = _b;
    output;
  end;
  if _nt and _nb then do;
    paramcd = 'HYLAW';
    param = 'ALT or AST >1.5 x ULN and Bilirubin >1.5 x ULN';
    aval = _t and _b;
    output;
  end;
run;

%addadsl(hy1, hy2,
  STUDYID SITEID TRT01P TRT01PN TRT01A TRT01AN AGE AGEGR1 AGEGR1N RACE RACEN SEX
  SAFFL TRTSDT TRTEDT)

data hy2;
  set hy2(rename=(trt01p=trtp trt01pn=trtpn trt01a=trta trt01an=trtan));
  length avalc $200;
  avalc = ifc(aval, 'Y', 'N');
  %ady(adt, ady)
run;

proc sort data=hy2;
  by usubjid paramcd;
run;

data bl;
  set hy2(where=(ablfl = 'Y'));
  keep usubjid paramcd base basec;
  base = aval;
  basec = avalc;
run;

data adlbhy1;
  merge hy2 bl;
  by usubjid paramcd;
  label
    trtp = 'Planned Treatment'
    trtpn = 'Planned Treatment (N)'
    trta = 'Actual Treatment'
    trtan = 'Actual Treatment (N)'
    paramcd = 'Parameter Code'
    param = 'Parameter'
    avisit = 'Analysis Visit'
    avisitn = 'Analysis Visit (N)'
    adt = 'Analysis Date'
    ady = 'Analysis Relative Day'
    avalc = 'Analysis Value (C)'
    aval = 'Analysis Value'
    basec = 'Baseline Value (C)'
    base = 'Baseline Value'
    ablfl = 'Baseline Record Flag'
    ontrtfl = 'On Treatment Record Flag';
run;

%finalize(adlbhy1, adlbhy, Hy%str(%')s Law Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SITEID TRTP TRTPN TRTA TRTAN AGE AGEGR1 AGEGR1N RACE RACEN
    SEX SAFFL TRTSDT TRTEDT PARAMCD PARAM AVISIT AVISITN ADT ADY AVALC AVAL BASEC
    BASE ABLFL ONTRTFL,
  keys=STUDYID USUBJID PARAMCD AVISITN)
