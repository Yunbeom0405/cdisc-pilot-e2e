/*******************************************************************************
Program : vs.sas
Purpose : Create SDTM VS
*******************************************************************************/

proc format;
  value $vstest
    'DIABP' = 'Diastolic Blood Pressure'
    'HEIGHT' = 'Height'
    'PULSE' = 'Pulse Rate'
    'SYSBP' = 'Systolic Blood Pressure'
    'TEMP' = 'Temperature'
    'WEIGHT' = 'Weight';

  value $stdunit
    'WEIGHT' = 'kg'
    'HEIGHT' = 'cm'
    'TEMP' = 'C'
    'SYSBP', 'DIABP' = 'mmHg'
    'PULSE' = 'beats/min';

  value $tpt
    '815' = 'AFTER LYING DOWN FOR 5 MINUTES'
    '816' = 'AFTER STANDING FOR 1 MINUTE'
    '817' = 'AFTER STANDING FOR 3 MINUTES';

  value $eltm
    '815' = 'PT5M'
    '816' = 'PT1M'
    '817' = 'PT3M';

  value $loc
    'PO' = 'ORAL CAVITY'
    'E' = 'EAR'
    'R' = 'RECTUM'
    'A' = 'AXILLA'
    other = ' ';
run;

/* one record per test from the three CRF forms */
data vs_wh;
  set raw_vs_wt_ht;
  length vstestcd vsorres vsorresu $200;
  vstestcd = 'WEIGHT';
  vsorres = weight;
  vsorresu = ifc(weight_unit = 'lb', 'LB', weight_unit);
  output;

  if missing(height) then return;
  vstestcd = 'HEIGHT';
  vsorres = height;
  vsorresu = height_unit;
  output;
run;

data vs_bp;
  set raw_vs_bp;
  length vstestcd vsorres vsorresu vspos vstpt vseltm vstptref $200;
  vstptnum = input(timing_code, best.);
  vspos = ifc(position = 'SU', 'SUPINE', 'STANDING');
  vstpt = put(timing_code, $tpt.);
  vseltm = put(timing_code, $eltm.);
  vstptref = catx(' ', 'PATIENT', vspos);

  vstestcd = 'PULSE';
  vsorres = heart_rate;
  vsorresu = 'beats/min';
  output;

  vsorresu = 'mmHg';
  vstestcd = 'SYSBP';
  vsorres = systolic;
  output;

  vstestcd = 'DIABP';
  vsorres = diastolic;
  output;
run;

data vs_tp;
  set raw_vs_temp;
  length vstestcd vsorres vsorresu vsloc $200;
  vstestcd = 'TEMP';
  vsorres = temperature;
  vsorresu = temp_unit;
  vsloc = put(temp_method, $loc.);
run;

data vs0;
  set vs_wh vs_bp vs_tp;
run;

proc sql;
  create table vs1 as
  select v.*, s.usubjid, s.visitnum, s.visit, s.visitdy, d.rfstdtc, d.rfxstdtc, d.rfxendtc
  from vs0 as v
  left join sdtm.svmap as s
    on v.subject = s.subject and v.folder = s.folder and v.visit_date = s.visit_date
  left join sdtm.dm as d on s.usubjid = d.usubjid;
quit;

data vs2;
  set vs1;
  length studyid domain vstest vsstresc vsstresu vsstat epoch vsdtc $200;
  studyid = 'CDISCPILOT01';
  domain = 'VS';
  vstest = put(vstestcd, $vstest.);
  if missing(vsorres) then vsstat = 'NOT DONE';

  /* standard unit per test; no unit collected, no standard value */
  _x = input(vsorres, best.);
  if vsorresu = 'LB' then _x = _x * 0.45359237;
  else if vsorresu = 'in' then _x = _x * 2.54;
  else if vsorresu = 'F' then _x = (_x - 32) * 5 / 9;

  if not missing(_x) and not missing(vsorresu) then do;
    vsstresn = round(_x, 0.01);
    vsstresc = strip(put(vsstresn, best12.));
    vsstresu = put(vstestcd, $stdunit.);
  end;

  %iso(visit_date, vsdtc)
  %predose(vsdtc)
  %fepoch(vsdtc)
  %dy(vsdtc, vsdy)
  _row = _n_;
run;

%lobxfl(vs2, vslobxfl, by=vstestcd vstptnum, res=vsorres, dtc=vsdtc)

proc sort data=vs2;
  by usubjid vstestcd vsdtc visitnum vstptnum;
run;

data vs3;
  set vs2;
  by usubjid;
  if first.usubjid then vsseq = 0;
  vsseq + 1;

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    vsseq = 'Sequence Number'
    vstestcd = 'Vital Signs Test Short Name'
    vstest = 'Vital Signs Test Name'
    vspos = 'Vital Signs Position of Subject'
    vsorres = 'Result or Finding in Original Units'
    vsorresu = 'Original Units'
    vsstresc = 'Character Result/Finding in Std Format'
    vsstresn = 'Numeric Result/Finding in Standard Units'
    vsstresu = 'Standard Units'
    vsstat = 'Completion Status'
    vsloc = 'Location of Vital Signs Measurement'
    vslobxfl = 'Last Observation Before Exposure Flag'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    visitdy = 'Planned Study Day of Visit'
    epoch = 'Epoch'
    vsdtc = 'Date/Time of Measurements'
    vsdy = 'Study Day of Vital Signs'
    vstpt = 'Planned Time Point Name'
    vstptnum = 'Planned Time Point Number'
    vseltm = 'Planned Elapsed Time from Time Point Ref'
    vstptref = 'Time Point Reference';
run;

%finalize(vs3, vs, Vital Signs,
  vars=STUDYID DOMAIN USUBJID VSSEQ VSTESTCD VSTEST VSPOS VSORRES VSORRESU
    VSSTRESC VSSTRESN VSSTRESU VSSTAT VSLOC VSLOBXFL VISITNUM VISIT VISITDY EPOCH
    VSDTC VSDY VSTPT VSTPTNUM VSELTM VSTPTREF,
  keys=STUDYID USUBJID VSTESTCD VISITNUM VSTPTNUM)
