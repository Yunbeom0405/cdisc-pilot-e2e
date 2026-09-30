/*******************************************************************************
Program : mh.sas
Purpose : Create SDTM MH
*******************************************************************************/

/* AD onset, historical diagnoses and the pre-existing conditions of the AE log */
data mh0;
  length mhspid mhterm mhllt mhdecod mhhlt mhhlgt mhcat mhbodsys mhsev
    mhdtc mhstdtc mhendtc $200;
  set raw_mh_ad_onset(in=pdx) raw_mh_history(in=hx)
    raw_ae(in=pre where=(onset_date = ''));

  if pdx then do;
    _ord = 1;
    mhcat = 'PRIMARY DIAGNOSIS';
    mhterm = "ALZHEIMER'S DISEASE";
    %iso(ad_onset_date, mhstdtc)
    %iso(visit_date, mhdtc)
  end;
  else if hx then do;
    _ord = 2;
    mhcat = 'HISTORICAL DIAGNOSIS';
    mhspid = cats('H', line);
    mhterm = upcase(strip(diagnosis));
    %iso(date_recovered, mhendtc)
    %iso(visit_date, mhdtc)
  end;
  else if pre then do;
    _ord = 3;
    mhcat = 'SIGNIFICANT PRE-EXISTING CONDITION';
    mhspid = event_code;
    mhterm = upcase(strip(description));
    mhsev = choosec(input(severity, 1.), 'MILD', 'MODERATE', 'SEVERE');
    %iso(recorded_date, mhdtc)
  end;

  if not pdx then do;
    mhllt = meddra_llt;
    mhdecod = meddra_pt;
    mhhlt = meddra_hlt;
    mhhlgt = meddra_hlgt;
    mhbodsys = meddra_soc;
  end;
run;

proc sql;
  create table mh1 as
  select distinct m.*, d.usubjid, d.rfstdtc
  from mh0 as m
  left join sdtm.dm as d on cats('01-', m.subject) = d.usubjid
  order by usubjid, _ord, mhspid;
quit;

data mh2;
  set mh1;
  by usubjid;
  length studyid domain visit $200;
  studyid = 'CDISCPILOT01';
  domain = 'MH';
  visitnum = 1;
  visit = 'SCREENING 1';
  %dy(mhdtc, mhdy)

  if first.usubjid then mhseq = 0;
  mhseq + 1;

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    mhseq = 'Sequence Number'
    mhspid = 'Sponsor-Defined Identifier'
    mhterm = 'Reported Term for the Medical History'
    mhllt = 'Lowest Level Term'
    mhdecod = 'Dictionary-Derived Term'
    mhhlt = 'High Level Term'
    mhhlgt = 'High Level Group Term'
    mhcat = 'Category for Medical History'
    mhbodsys = 'Body System or Organ Class'
    mhsev = 'Severity/Intensity'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    mhdtc = 'Date/Time of History Collection'
    mhstdtc = 'Start Date/Time of Medical History Event'
    mhendtc = 'End Date/Time of Medical History Event'
    mhdy = 'Study Day of History Collection';
run;

%finalize(mh2, mh, Medical History,
  vars=STUDYID DOMAIN USUBJID MHSEQ MHSPID MHTERM MHLLT MHDECOD MHHLT MHHLGT
    MHCAT MHBODSYS MHSEV VISITNUM VISIT MHDTC MHSTDTC MHENDTC MHDY,
  keys=STUDYID USUBJID MHCAT MHSPID)
