/*******************************************************************************
Program : qs.sas
Purpose : Create SDTM QS (MMSE, ADAS-Cog, CIBIC+ as ADCS-CGIC)
*******************************************************************************/

proc format;
  value $qstest
    'MMITM01' = 'WHAT IS THE (YEAR) (SEASON) (DATE) ?'
    'MMITM02' = 'WHERE ARE WE: (STATE) (COUNTRY) (TOWN) ?'
    'MMITM03' = 'NAME 3 OBJECTS: 1 SECOND TO SAY EACH.'
    'MMITM04' = "SERIAL 7'S. 1 POINT FOR EACH CORRECT."
    'MMITM05' = 'ASK FOR THE 3 OBJECTS REPEATED ABOVE.'
    'MMITM06' = 'NAME A PENCIL, AND WATCH (2 POINTS)'
    'ACITM01' = 'WORD RECALL TASK'
    'ACITM02' = 'NAMING OBJECTS AND FINGERS (REFER TO 5 C'
    'ACITM03' = 'DELAYED WORD RECALL'
    'ACITM04' = 'COMMANDS'
    'ACITM05' = 'CONSTRUCTIONAL PRAXIS'
    'ACITM06' = 'IDEATIONAL PRAXIS'
    'ACITM07' = 'ORIENTATION'
    'ACITM08' = 'WORD RECOGNITION'
    'ACITM09' = 'ATTENTION/VISUAL SEARCH TASK'
    'ACITM10' = 'MAZE SOLUTION'
    'ACITM11' = 'SPOKEN LANGUAGE ABILITY'
    'ACITM12' = 'COMPREHENSION OF SPOKEN LANGUAGE'
    'ACITM13' = 'WORD FINDING DIFFICULTY IN SPONTANEOUS S'
    'ACITM14' = 'RECALL OF TEST INSTRUCTIONS'
    'ACGC0101' = 'ACGC01-Clinical Impression of Change'
    'QSALL' = 'Questionnaire (all items)';

  value $cibic
    '1' = 'MARKED IMPROVEMENT'
    '2' = 'MODERATE IMPROVEMENT'
    '3' = 'MINIMAL IMPROVEMENT'
    '4' = 'NO CHANGE'
    '5' = 'MINIMAL WORSENING'
    '6' = 'MODERATE WORSENING'
    '7' = 'MARKED WORSENING'
    other = ' ';
run;

/* one record per item */
data qs0;
  length qscat qsscat qstestcd qsorres qsorresu qsstresc qsstat $200;
  set raw_qs_mmse(in=mm) raw_qs_adas(in=ad) raw_qs_cibic(in=ci);
  array mmi{6} $200 item1-item6;
  array adi{14} $200 item01-item14;
  array scat{6} $30 _temporary_ ('ORIENTATION', 'ORIENTATION', 'REGISTRATION',
    'ATTENTION AND CALCULATION', 'RECALL', 'LANGUAGE');

  if mm then qscat = 'MINI-MENTAL STATE';
  else if ad then qscat = "ALZHEIMER'S DISEASE ASSESSMENT SCALE";
  else qscat = 'ADCS-CGIC';

  /* page not done: one QSALL record */
  if not_obtained = 'X' then do;
    qstestcd = 'QSALL';
    qsstat = 'NOT DONE';
    output;
    return;
  end;

  if mm then do i = 1 to 6;
    qstestcd = cats('MMITM0', i);
    qsscat = scat{i};
    qsorres = mmi{i};
    link result;
  end;
  else if ad then do i = 1 to 14;
    qstestcd = cats('ACITM', put(i, z2.));
    qsorres = adi{i};
    if i = 10 and not missing(qsorres) then qsorresu = 's';
    else qsorresu = '';
    link result;
  end;
  else do;
    qstestcd = 'ACGC0101';
    qsorres = put(cibic, $cibic.);
    link result;
  end;
  return;

result:
  qsstat = '';
  qsstresc = ifc(ci, cibic, qsorres);   /* box code for CIBIC */
  qsstresn = input(qsstresc, best.);
  if missing(qsorres) then qsstat = 'NOT DONE';
  output;
  return;
run;

proc sql;
  create table qs1 as
  select q.*, s.usubjid, s.visitnum, s.visit, s.visitdy, d.rfstdtc, d.rfxstdtc, d.rfxendtc
  from qs0 as q
  left join sdtm.svmap as s
    on q.subject = s.subject and q.folder = s.folder and q.visit_date = s.visit_date
  left join sdtm.dm as d on s.usubjid = d.usubjid;
quit;

data qs2;
  set qs1;
  length studyid domain qstest qsstresu epoch qsdtc $200;
  studyid = 'CDISCPILOT01';
  domain = 'QS';
  qstest = put(qstestcd, $qstest.);
  qsstresu = qsorresu;

  %iso(visit_date, qsdtc)
  %predose(qsdtc)
  %fepoch(qsdtc)
  %dy(qsdtc, qsdy)
  _row = _n_;
run;

%lobxfl(qs2, qslobxfl, by=qscat qstestcd, res=qsorres, dtc=qsdtc)

proc sort data=qs2;
  by usubjid qscat qstestcd visitnum;
run;

data qs3;
  set qs2;
  by usubjid;
  if first.usubjid then qsseq = 0;
  qsseq + 1;

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    qsseq = 'Sequence Number'
    qstestcd = 'Question Short Name'
    qstest = 'Question Name'
    qscat = 'Category of Question'
    qsscat = 'Subcategory for Question'
    qsorres = 'Finding in Original Units'
    qsorresu = 'Original Units'
    qsstresc = 'Character Result/Finding in Std Format'
    qsstresn = 'Numeric Finding in Standard Units'
    qsstresu = 'Standard Units'
    qsstat = 'Completion Status'
    qslobxfl = 'Last Observation Before Exposure Flag'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    visitdy = 'Planned Study Day of Visit'
    epoch = 'Epoch'
    qsdtc = 'Date/Time of Finding'
    qsdy = 'Study Day of Finding';
run;

%finalize(qs3, qs, Questionnaires,
  vars=STUDYID DOMAIN USUBJID QSSEQ QSTESTCD QSTEST QSCAT QSSCAT QSORRES QSORRESU
    QSSTRESC QSSTRESN QSSTRESU QSSTAT QSLOBXFL VISITNUM VISIT VISITDY EPOCH QSDTC QSDY,
  keys=STUDYID USUBJID QSCAT QSTESTCD VISITNUM)
