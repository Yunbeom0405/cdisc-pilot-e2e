/*******************************************************************************
Program : ds.sas
Purpose : Create SDTM DS, SUPPDS and RELREC
*******************************************************************************/

proc format;
  value $dsterm
    '1' = 'PROTOCOL COMPLETED'
    '3' = 'ADVERSE EVENT'
    '4' = 'DEATH'
    '8' = 'LACK OF EFFICACY, PATIENT/CAREGIVER PERCEPTION'
    '9' = 'LACK OF EFFICACY, PHYSICIAN PERCEPTION'
    '11' = 'UNABLE TO CONTACT PATIENT (LOST TO FOLLOW-UP)'
    '13' = 'PERSONAL CONFLICT OR OTHER PATIENT/CAREGIVER DECISION'
    '14' = 'PROTOCOL ENTRY CRITERIA NOT MET'
    '18' = 'SPONSOR DECISION (STUDY OR PATIENT DISCONTINUED BY THE SPONSOR)'
    '22' = 'PHYSICIAN DECISION'
    '243' = 'PROTOCOL VIOLATION';

  value $dsdecod
    '1' = 'COMPLETED'
    '3' = 'ADVERSE EVENT'
    '4' = 'DEATH'
    '8', '9' = 'LACK OF EFFICACY'
    '11' = 'LOST TO FOLLOW-UP'
    '13' = 'WITHDRAWAL BY SUBJECT'
    '22' = 'PHYSICIAN DECISION'
    '14', '243' = 'PROTOCOL DEVIATION'
    '18' = 'STUDY TERMINATED BY SPONSOR';
run;

proc sql;
  create table subj as
  select dm.usubjid, dm.rfstdtc, dm.rfxstdtc, dm.rfxendtc, dm.rficdtc,
    i.subject_status, i.randomization_datetime, i.screen_fail_datetime,
    s.visit_no, s.visit_date as ds_date, s.reason, s.reason_specify,
    s.ae_code, s.entry_criterion, v.visit_date as v201_date
  from sdtm.dm as dm
  left join raw_irt_randomization as i
    on i.site_id = dm.siteid and i.subject_id = dm.subjid
  left join raw_ds_summary as s on s.subject = catx('-', dm.siteid, dm.subjid)
  left join raw_visits(where=(folder = 'V201')) as v
    on v.subject = catx('-', dm.siteid, dm.subjid);
quit;

data ds0;
  set subj;
  length studyid domain dsterm dsdecod dscat dsscat visit dsstdtc $200;
  studyid = 'CDISCPILOT01';
  domain = 'DS';
  %iso(ds_date, _dsdate)
  %iso(v201_date, _v201)

  dscat = 'PROTOCOL MILESTONE';
  dsterm = 'INFORMED CONSENT OBTAINED';
  dsdecod = dsterm;
  dsstdtc = rficdtc;
  output;

  if subject_status = 'Screen Failed' then do;
    dscat = 'DISPOSITION EVENT';
    dsscat = 'STUDY PARTICIPATION';
    dsterm = 'SCREEN FAILURE';
    dsdecod = dsterm;
    dsstdtc = screen_fail_datetime;
    output;
  end;
  else do;
    dsterm = 'RANDOMIZED';
    dsdecod = dsterm;
    dsstdtc = randomization_datetime;
    output;

    dscat = 'DISPOSITION EVENT';
    dsscat = 'STUDY TREATMENT';
    dsterm = coalescec(reason_specify, put(reason, $dsterm.));
    dsdecod = put(reason, $dsdecod.);
    visitnum = input(visit_no, best.);
    visit = put(visitnum, visit.);
    dsstdtc = _dsdate;
    output;

    /* study participation: completed if seen at retrieval visit, else same as treatment */
    dsscat = 'STUDY PARTICIPATION';
    if _v201 > _dsdate then do;
      dsterm = 'COMPLETED RETRIEVAL VISIT';
      dsdecod = 'COMPLETED';
      visitnum = 201;
      visit = put(visitnum, visit.);
      dsstdtc = _v201;
    end;
    output;
  end;
run;

data ds1;
  set ds0;
  length epoch $200;
  if dscat = 'PROTOCOL MILESTONE' then epoch = 'SCREENING';
  else %epoch(dsstdtc)
  %dy(dsstdtc, dsstdy)
  /* fixed record order */
  if dsdecod = 'INFORMED CONSENT OBTAINED' then _ord = 1;
  else if dsdecod = 'RANDOMIZED' then _ord = 2;
  else if dsscat = 'STUDY TREATMENT' then _ord = 3;
  else if dsscat = 'STUDY PARTICIPATION' then _ord = 4;
run;

proc sort data=ds1;
  by usubjid _ord;
run;

data ds2;
  set ds1;
  by usubjid;
  if first.usubjid then dsseq = 0;
  dsseq + 1;

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    dsseq = 'Sequence Number'
    dsterm = 'Reported Term for the Disposition Event'
    dsdecod = 'Standardized Disposition Term'
    dscat = 'Category for Disposition Event'
    dsscat = 'Subcategory for Disposition Event'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    epoch = 'Epoch'
    dsstdtc = 'Start Date/Time of Disposition Event'
    dsstdy = 'Study Day of Start of Disposition Event';
run;

%finalize(ds2, ds, Disposition,
  vars=STUDYID DOMAIN USUBJID DSSEQ DSTERM DSDECOD DSCAT DSSCAT VISITNUM VISIT
    EPOCH DSSTDTC DSSTDY,
  keys=STUDYID USUBJID DSSEQ)

/* SUPPDS */
data suppds0;
  set ds2(where=(dsscat = 'STUDY TREATMENT' and entry_criterion ne ''));
  length rdomain idvar idvarval qnam qlabel qval qorig qeval $200;
  rdomain = 'DS';
  idvar = 'DSSEQ';
  idvarval = strip(put(dsseq, best.));
  qnam = 'ENTCRIT';
  qlabel = 'Protocol Entry Criteria Not Met';
  qval = entry_criterion;
  qorig = 'CRF';
  qeval = '';

  label
    rdomain = 'Related Domain Abbreviation'
    idvar = 'Identifying Variable'
    idvarval = 'Identifying Variable Value'
    qnam = 'Qualifier Variable Name'
    qlabel = 'Qualifier Variable Label'
    qval = 'Data Value'
    qorig = 'Origin'
    qeval = 'Evaluator';
run;

%finalize(suppds0, suppds, Supplemental Qualifiers for DS,
  vars=STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL,
  keys=STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM)

/* RELREC: DS discontinuation due to AE <-> AE */
data relrec0;
  set ds2(where=(dsscat = 'STUDY TREATMENT' and ae_code ne ''));
  length rdomain idvar idvarval reltype relid $200;
  reltype = '';
  relid = 'DSAE';

  rdomain = 'DS';
  idvar = 'DSSEQ';
  idvarval = strip(put(dsseq, best.));
  output;

  rdomain = 'AE';
  idvar = 'AESPID';
  idvarval = ae_code;
  output;

  label
    rdomain = 'Related Domain Abbreviation'
    idvar = 'Identifying Variable'
    idvarval = 'Identifying Variable Value'
    reltype = 'Relationship Type'
    relid = 'Relationship Identifier';
run;

%finalize(relrec0, relrec, Related Records,
  vars=STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID,
  keys=STUDYID USUBJID RDOMAIN IDVAR IDVARVAL RELID)
