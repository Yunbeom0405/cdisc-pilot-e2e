/*******************************************************************************
Program : sc.sas
Purpose : Create SDTM SC
*******************************************************************************/

proc sql;
  create table sc0 as
  select s.*, d.usubjid, d.rfstdtc, d.rfxstdtc, d.rfxendtc
  from raw_sc_su(where=(edu_years ne '')) as s
  left join sdtm.dm as d on cats('01-', s.subject) = d.usubjid;
quit;

data sc1;
  set sc0;
  length studyid domain sctestcd sctest scorres scorresu scstresc scstresu
    visit epoch scdtc $200;
  studyid = 'CDISCPILOT01';
  domain = 'SC';
  scseq = 1;
  sctestcd = 'EDUYRNUM';
  sctest = 'Number of Years of Education';

  /* free text such as '12 yrs' keeps the number only */
  scorres = strip(edu_years);
  scorresu = 'YEARS';
  scstresn = input(compress(scorres, , 'kd'), best.);
  scstresc = strip(put(scstresn, best.));
  scstresu = 'YEARS';

  visitnum = 1;
  visit = 'SCREENING 1';
  %iso(visit_date, scdtc)
  %epoch(scdtc)
  %dy(scdtc, scdy)

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    scseq = 'Sequence Number'
    sctestcd = 'Subject Characteristic Short Name'
    sctest = 'Subject Characteristic'
    scorres = 'Result or Finding in Original Units'
    scorresu = 'Original Units'
    scstresc = 'Character Result/Finding in Std Format'
    scstresn = 'Numeric Result/Finding in Standard Units'
    scstresu = 'Standard Units'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    epoch = 'Epoch'
    scdtc = 'Date/Time of Collection'
    scdy = 'Study Day of Examination';
run;

%finalize(sc1, sc, Subject Characteristics,
  vars=STUDYID DOMAIN USUBJID SCSEQ SCTESTCD SCTEST SCORRES SCORRESU SCSTRESC
    SCSTRESN SCSTRESU VISITNUM VISIT EPOCH SCDTC SCDY,
  keys=STUDYID USUBJID SCTESTCD)
