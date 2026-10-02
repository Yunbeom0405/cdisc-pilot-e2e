/*******************************************************************************
Program : sv.sas
Purpose : Create SDTM SV and the visit lookup (SDTM.SVMAP) used by VS, QS and LB
*******************************************************************************/

/* unscheduled lab collections on a date without a visit page are unscheduled visits */
data labvis;
  set raw_lab_results(keep=patient_id req_visit status collection_dt where=(req_visit = 'UNSCH' and status = 'FINAL'));
  length subject folder visit_date $200;
  subject = cats(substr(patient_id, 1, 3), '-', substr(patient_id, 4));
  folder = 'UNS';
  _d = input(substr(collection_dt, 1, 10), e8601da.);
  _s = put(_d, date9.);
  visit_date = catx(' ', substr(_s, 1, 2), substr(_s, 3, 3), substr(_s, 6));
  keep subject folder visit_date _d;
run;

proc sort data=labvis nodupkey;
  by subject _d;
run;

proc sql;
  create table labvis2 as
  select l.subject, l.folder, l.visit_date
  from labvis as l
  where not exists (select 1 from raw_visits as v
    where v.subject = l.subject and input(compress(v.visit_date), date9.) = l._d);
quit;

data sv0;
  set raw_visits labvis2;
  length usubjid $200;
  usubjid = cats('01-', subject);
  _dt = input(compress(visit_date), date9.);
  _uns = (folder = 'UNS');
  _tel = (prxmatch('/^V\d+T$/', strip(folder)) > 0);

  if folder = 'ET' then visitnum = input(visit_no, best.);
  else if folder = 'V3E' then visitnum = 3.5;
  else if _tel then visitnum = input(compress(folder, 'VT'), best.) + 0.5;
  else if not _uns then visitnum = input(compress(folder, 'V'), best.);
run;

proc sort data=sv0;
  by usubjid _dt _uns visitnum;
run;

/* unscheduled visit: previous planned visit + .1, .2 */
data sv1;
  set sv0;
  by usubjid;
  retain _base _n;
  if first.usubjid then do;
    _base = 0;
    _n = 0;
  end;
  if not _uns then do;
    _base = visitnum;
    _n = 0;
  end;
  else do;
    _n + 1;
    visitnum = round(_base + _n / 10, 0.01);
  end;
run;

proc sql;
  create table sv2 as
  select s.*, t.visitdy as _tvdy, d.rfstdtc, d.rfxstdtc, d.rfxendtc
  from sv1 as s
  left join tv as t on s.visitnum = t.visitnum
  left join sdtm.dm as d on s.usubjid = d.usubjid;
quit;

data sv3;
  set sv2;
  length studyid domain visit svpresp svcntmod epoch svstdtc svendtc $200;
  studyid = 'CDISCPILOT01';
  domain = 'SV';

  if _uns then visit = catx(' ', 'UNSCHEDULED', put(visitnum, best.));
  else do;
    visit = put(visitnum, visit.);
    svpresp = 'Y';
    visitdy = _tvdy;
  end;
  svcntmod = ifc(_tel, 'TELEPHONE CALL', 'IN PERSON');

  %iso(visit_date, svstdtc)
  svendtc = svstdtc;
  %epoch(svstdtc)
  %dy(svstdtc, svstdy)
  %dy(svendtc, svendy)

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    svpresp = 'Pre-specified'
    svcntmod = 'Contact Mode'
    visitdy = 'Planned Study Day of Visit'
    epoch = 'Epoch'
    svstdtc = 'Start Date/Time of Observation'
    svendtc = 'End Date/Time of Observation'
    svstdy = 'Study Day of Start of Observation'
    svendy = 'Study Day of End of Observation';
run;

data sdtm.svmap;
  set sv3(keep=subject folder visit_date usubjid visitnum visit visitdy svpresp svstdtc);
run;

%finalize(sv3, sv, Subject Visits,
  vars=STUDYID DOMAIN USUBJID VISITNUM VISIT SVPRESP SVCNTMOD VISITDY EPOCH
    SVSTDTC SVENDTC SVSTDY SVENDY,
  keys=STUDYID USUBJID VISITNUM)
