/*******************************************************************************
Program : ae.sas
Purpose : Create SDTM AE
*******************************************************************************/

/* records without onset date go to MH */
proc sql;
  create table ae0 as
  select distinct a.*, d.rfstdtc, d.rfxstdtc, d.rfxendtc
  from raw_ae as a
  left join sdtm.dm as d on cats('01-', a.subject) = d.usubjid
  where a.onset_date ne '';
quit;

data ae1;
  set ae0;
  length studyid domain usubjid aespid aeterm aellt aedecod aehlt aehlgt aebodsys
    aesoc aesev aeser aerel epoch aedtc aestdtc aeendtc $200;
  array sflag{8} $200 aesdth aeslife aesdisab aeshosp aescong aescan aesod aesmie;

  studyid = 'CDISCPILOT01';
  domain = 'AE';
  usubjid = cats('01-', subject);
  aespid = event_code;
  aeterm = upcase(strip(description));

  aellt = meddra_llt;
  aedecod = meddra_pt;
  aehlt = meddra_hlt;
  aehlgt = meddra_hlgt;
  aebodsys = meddra_soc;
  aesoc = meddra_soc;

  aesev = choosec(input(severity, 1.), 'MILD', 'MODERATE', 'SEVERE');
  aeser = upcase(substr(serious, 1, 1));
  if not missing(relationship) then
    aerel = choosec(input(relationship, 1.), 'NONE', 'REMOTE', 'POSSIBLE', 'PROBABLE');

  do i = 1 to 8;
    sflag{i} = ifc(findw(serious_codes, cats(i), ', '), 'Y', 'N');
  end;

  %iso(recorded_date, aedtc)
  %iso(onset_date, aestdtc)
  %iso(stop_date, aeendtc)
  %epoch(aestdtc)
  %dy(aestdtc, aestdy)
  %dy(aeendtc, aeendy)

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    aespid = 'Sponsor-Defined Identifier'
    aeterm = 'Reported Term for the Adverse Event'
    aellt = 'Lowest Level Term'
    aedecod = 'Dictionary-Derived Term'
    aehlt = 'High Level Term'
    aehlgt = 'High Level Group Term'
    aebodsys = 'Body System or Organ Class'
    aesoc = 'Primary System Organ Class'
    aesev = 'Severity/Intensity'
    aeser = 'Serious Event'
    aerel = 'Causality'
    aescan = 'Involves Cancer'
    aescong = 'Congenital Anomaly or Birth Defect'
    aesdisab = 'Persist or Signif Disability/Incapacity'
    aesdth = 'Results in Death'
    aeshosp = 'Requires or Prolongs Hospitalization'
    aeslife = 'Is Life Threatening'
    aesod = 'Occurred with Overdose'
    aesmie = 'Other Medically Important Serious Event'
    epoch = 'Epoch'
    aedtc = 'Date/Time of Collection'
    aestdtc = 'Start Date/Time of Adverse Event'
    aeendtc = 'End Date/Time of Adverse Event'
    aestdy = 'Study Day of Start of Adverse Event'
    aeendy = 'Study Day of End of Adverse Event';
run;

proc sort data=ae1;
  by usubjid aespid aedtc;
run;

data ae2;
  set ae1;
  by usubjid;
  if first.usubjid then aeseq = 0;
  aeseq + 1;
  label aeseq = 'Sequence Number';
run;

%finalize(ae2, ae, Adverse Events,
  vars=STUDYID DOMAIN USUBJID AESEQ AESPID AETERM AELLT AEDECOD AEHLT AEHLGT
    AEBODSYS AESOC AESEV AESER AEREL AESCAN AESCONG AESDISAB AESDTH AESHOSP
    AESLIFE AESOD AESMIE EPOCH AEDTC AESTDTC AEENDTC AESTDY AEENDY,
  keys=STUDYID USUBJID AESPID AEDTC)
