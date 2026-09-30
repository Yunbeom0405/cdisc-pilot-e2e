/*******************************************************************************
Program : ex.sas
Purpose : Create SDTM EX
*******************************************************************************/

proc sql;
  create table ex0 as
  select e.*, input(compress(e.visit_date), date9.) as _dt, i.treatment_arm,
    f.final_dose_date, d.usubjid, d.rfstdtc, d.rfxstdtc, d.rfxendtc
  from raw_ex_dosage as e
  left join raw_irt_randomization as i on e.subject = catx('-', i.site_id, i.subject_id)
  left join raw_final_dose as f on e.subject = f.subject
  left join sdtm.dm as d on cats('01-', e.subject) = d.usubjid;
quit;

/* backwards, so the start of the next interval is known */
proc sort data=ex0;
  by usubjid descending _dt;
run;

data ex1;
  set ex0;
  by usubjid;
  length studyid domain extrt exdosu exdosfrm exdosfrq exroute visit epoch exstdtc exendtc $200;
  retain _next;
  studyid = 'CDISCPILOT01';
  domain = 'EX';

  extrt = ifc(treatment_arm = 'Placebo', 'PLACEBO', 'XANOMELINE');
  _dose25 = input(patch25_per_day, best.) * 27 * (treatment_arm = 'Xanomeline High Dose');
  _dose50 = input(patch50_per_day, best.) * 54 * (treatment_arm ne 'Placebo');
  exdose = _dose25 + _dose50;
  exdosu = 'mg';
  exdosfrm = 'PATCH';
  exdosfrq = 'QD';
  exroute = 'TRANSDERMAL';

  /* the interval starts the day after the visit, so VISITNUM comes from the folder */
  visitnum = input(compress(folder, 'V'), best.);
  visit = put(visitnum, visit.);

  %iso(visit_date, exstdtc)
  if first.usubjid then do;
    %iso(final_dose_date, exendtc)
  end;
  else exendtc = put(_next - 1, e8601da.);
  _next = _dt;

  %epoch(exstdtc)
  %dy(exstdtc, exstdy)
  %dy(exendtc, exendy)
run;

proc sql;
  create table ex2 as
  select e.*, t.visitdy
  from ex1 as e
  left join tv as t on e.visitnum = t.visitnum
  order by usubjid, exstdtc;
quit;

data ex3;
  set ex2;
  by usubjid;
  if first.usubjid then exseq = 0;
  exseq + 1;

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    exseq = 'Sequence Number'
    extrt = 'Name of Treatment'
    exdose = 'Dose'
    exdosu = 'Dose Units'
    exdosfrm = 'Dose Form'
    exdosfrq = 'Dosing Frequency per Interval'
    exroute = 'Route of Administration'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    visitdy = 'Planned Study Day of Visit'
    epoch = 'Epoch'
    exstdtc = 'Start Date/Time of Treatment'
    exendtc = 'End Date/Time of Treatment'
    exstdy = 'Study Day of Start of Treatment'
    exendy = 'Study Day of End of Treatment';
run;

%finalize(ex3, ex, Exposure,
  vars=STUDYID DOMAIN USUBJID EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM EXDOSFRQ EXROUTE
    VISITNUM VISIT VISITDY EPOCH EXSTDTC EXENDTC EXSTDY EXENDY,
  keys=STUDYID USUBJID EXTRT EXSTDTC)
