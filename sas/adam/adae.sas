/*******************************************************************************
Program : adae.sas
Purpose : Create ADaM ADAE
*******************************************************************************/

proc format;
invalue sevn
'MILD' = 1
'MODERATE' = 2
'SEVERE' = 3;
value $relgr
'PROBABLE', 'POSSIBLE', ' ' = 'RELATED'
other = 'NOT RELATED';
/* dermatologic events, CSR Table 12-2 */
value $cq01_
'APPLICATION SITE BLEEDING', 'APPLICATION SITE DERMATITIS', 'APPLICATION SITE DESQUAMATION',
'APPLICATION SITE DISCHARGE', 'APPLICATION SITE DISCOLOURATION', 'APPLICATION SITE ERYTHEMA',
'APPLICATION SITE INDURATION', 'APPLICATION SITE IRRITATION', 'APPLICATION SITE PAIN',
'APPLICATION SITE PERSPIRATION', 'APPLICATION SITE PRURITUS', 'APPLICATION SITE REACTION',
'APPLICATION SITE SWELLING', 'APPLICATION SITE URTICARIA', 'APPLICATION SITE VESICLES',
'APPLICATION SITE WARMTH', 'ACTINIC KERATOSIS', 'BLISTER', 'DERMATITIS CONTACT',
'DRUG ERUPTION', 'ERYTHEMA', 'PRURITUS', 'PRURITUS GENERALISED', 'RASH', 'RASH ERYTHEMATOUS',
'RASH MACULO-PAPULAR', 'RASH PRURITIC', 'SKIN EXFOLIATION', 'SKIN IRRITATION',
'SKIN ODOUR ABNORMAL', 'SKIN ULCER', 'URTICARIA' = 'DERMATOLOGIC EVENTS'
other = ' ';
run;

/* AEs linked in RELREC to a treatment stop for ADVERSE EVENT */
proc sql;
  create table dcae as
  select distinct a.usubjid, a.idvarval as aespid length=200
  from sdtm.relrec(where=(rdomain = 'AE')) as a
  inner join sdtm.relrec(where=(rdomain = 'DS')) as b
    on a.usubjid = b.usubjid and a.relid = b.relid
  inner join sdtm.ds as d
    on b.usubjid = d.usubjid and input(b.idvarval, best.) = d.dsseq
  where d.dsdecod = 'ADVERSE EVENT';
quit;

proc sql;
  create table ae0 as
  select a.*, (c.usubjid ne '') as _dc
  from sdtm.ae as a
  left join dcae as c on a.usubjid = c.usubjid and a.aespid = c.aespid;
quit;

%addadsl(ae0, ae1,
  STUDYID SITEID TRT01A TRT01AN AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL TRTSDT TRTEDT)

data adae1;
  set ae1(rename=(trt01a=trta trt01an=trtan));
  length relgr1 astdtf aduru trtemfl dctrtfl cq01nam $200;

  aesevn = input(aesev, sevn.);
  relgr1 = put(aerel, $relgr.);
  cq01nam = put(aedecod, $cq01_.);

  /* partial start date: first of month/year, or first dose if same month/year */
  if length(aestdtc) = 10 then astdt = input(aestdtc, e8601da.);
  else if length(aestdtc) = 7 then do;
    astdtf = 'D';
    if trtsdt ne . and aestdtc = put(trtsdt, yymmd7.) then astdt = trtsdt;
    else astdt = input(cats(aestdtc, '-01'), e8601da.);
  end;
  else if length(aestdtc) = 4 then do;
    astdtf = 'M';
    if trtsdt ne . and aestdtc = put(year(trtsdt), 4.) then astdt = trtsdt;
    else astdt = mdy(1, 1, input(aestdtc, 4.));
  end;
  %dt(aeendtc, aendt)
  format astdt date9.;

  %ady(astdt, astdy)
  %ady(aendt, aendy)
  if astdt ne . and aendt ne . then do;
    adurn = aendt - astdt + 1;
    aduru = 'DAY';
  end;

  if trtsdt ne . and astdt >= trtsdt then trtemfl = 'Y';
  if _dc then dctrtfl = 'Y';

  label
    trta = 'Actual Treatment'
    trtan = 'Actual Treatment (N)'
    aesevn = 'Severity/Intensity (N)'
    relgr1 = 'Pooled Causality Group 1'
    astdt = 'Analysis Start Date'
    astdtf = 'Analysis Start Date Imputation Flag'
    astdy = 'Analysis Start Relative Day'
    aendt = 'Analysis End Date'
    aendy = 'Analysis End Relative Day'
    adurn = 'Analysis Duration (N)'
    aduru = 'Analysis Duration Units'
    trtemfl = 'Treatment Emergent Analysis Flag'
    dctrtfl = 'AE Led to Treatment Discontinuation Flag'
    cq01nam = 'Customized Query 01 Name';
run;

%first(adae1, aoccfl, by=usubjid, order=astdt aeseq, key=usubjid aeseq, where=trtemfl = 'Y')
%first(adae1, aoccsfl, by=usubjid aebodsys, order=astdt aeseq, key=usubjid aeseq, where=trtemfl = 'Y')
%first(adae1, aoccpfl, by=usubjid aebodsys aedecod, order=astdt aeseq, key=usubjid aeseq,
  where=trtemfl = 'Y')
%first(adae1, aoccifl, by=usubjid, order=descending aesevn astdt aeseq, key=usubjid aeseq,
  where=trtemfl = 'Y')
%first(adae1, aoccsifl, by=usubjid aebodsys, order=descending aesevn astdt aeseq,
  key=usubjid aeseq, where=trtemfl = 'Y')
%first(adae1, aoccpifl, by=usubjid aebodsys aedecod, order=descending aesevn astdt aeseq,
  key=usubjid aeseq, where=trtemfl = 'Y')
%first(adae1, aocc01fl, by=usubjid, order=astdt aeseq, key=usubjid aeseq,
  where=trtemfl = 'Y' and cq01nam ne '')

data adae1;
  set adae1;
  label
    aoccfl = '1st Occurrence of Any AE Flag'
    aoccsfl = '1st Occurrence of SOC Flag'
    aoccpfl = '1st Occurrence of Preferred Term Flag'
    aoccifl = '1st Max Sev./Int. Occurrence Flag'
    aoccsifl = '1st Max Sev./Int. Occur Within SOC Flag'
    aoccpifl = '1st Max Sev./Int. Occur Within PT Flag'
    aocc01fl = '1st Occurrence of CQ01 Flag';
run;

%finalize(adae1, adae, Adverse Events Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SITEID TRTA TRTAN AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL
    TRTSDT TRTEDT AESEQ AETERM AELLT AEDECOD AEHLT AEHLGT AEBODSYS AESOC AESEV
    AESEVN AESER AEREL RELGR1 AESCAN AESCONG AESDISAB AESDTH AESHOSP AESLIFE AESOD
    AESMIE ASTDT ASTDTF ASTDY AENDT AENDY ADURN ADURU TRTEMFL DCTRTFL AOCCFL AOCCSFL
    AOCCPFL AOCCIFL AOCCSIFL AOCCPIFL CQ01NAM AOCC01FL,
  keys=STUDYID USUBJID AESEQ)
