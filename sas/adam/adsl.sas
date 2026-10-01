/*******************************************************************************
Program : adsl.sas
Purpose : Create ADaM ADSL
*******************************************************************************/

proc format;
invalue trtn
'Placebo' = 0
'Xanomeline Low Dose' = 54
'Xanomeline High Dose' = 81;
invalue racen
'WHITE' = 1
'BLACK OR AFRICAN AMERICAN' = 2
'ASIAN' = 3
'OTHER' = 4;
value agegr
low -< 65 = '<65'
65 - 80 = '65-80'
80 <- high = '>80';
value agegrn
low -< 65 = '1'
65 - 80 = '2'
80 <- high = '3';
value bmigr
low -< 25 = '<25'
25 -< 30 = '25-<30'
30 - high = '>=30';
value durgr
low -< 12 = '<12'
12 - high = '>=12';
run;

/* sites with fewer than 3 randomized subjects in any arm are pooled */
proc sql;
  create table sitegr as
  select siteid, ifc(count(distinct arm) < 3 or min(n) < 3, '900', siteid) as sitegr1 length=3
  from (select siteid, arm, count(*) as n from sdtm.dm where arm ne '' group by siteid, arm)
  group by siteid;
quit;

/* cumulative dose: daily dose times days of each EX interval */
proc sql;
  create table dose as
  select e.usubjid,
    sum(e.exdose * (input(coalescec(e.exendtc, d.rfxendtc, d.rfendtc), e8601da.)
      - input(e.exstdtc, e8601da.) + 1)) as cumdose
  from sdtm.ex as e
  left join sdtm.dm as d on e.usubjid = d.usubjid
  group by e.usubjid;
quit;

/* efficacy population: baseline and post-baseline ADAS-Cog, post-baseline CIBIC+ */
proc sql;
  create table eff as
  select usubjid,
    max(qscat = "ALZHEIMER'S DISEASE ASSESSMENT SCALE" and visitnum = 3) as adas_bl,
    max(qscat = "ALZHEIMER'S DISEASE ASSESSMENT SCALE" and visitnum > 3) as adas_post,
    max(qscat = 'ADCS-CGIC' and visitnum > 3) as cibic_post
  from sdtm.qs
  where qsstat = ''
  group by usubjid;
quit;

proc sql;
  create table comp as
  select usubjid,
    max(visitnum = 8) as comp8, max(visitnum = 10) as comp16, max(visitnum = 12) as comp24
  from sdtm.sv
  where svpresp = 'Y'
  group by usubjid;
quit;

/* MMSE total: null unless all 6 items are present */
proc sql;
  create table mmse as
  select usubjid, ifn(n(qsstresn) = 6, sum(qsstresn), .) as mmsetot
  from sdtm.qs
  where qscat = 'MINI-MENTAL STATE' and qslobxfl = 'Y'
  group by usubjid;
quit;

proc sql;
  create table adsl0 as
  select d.*, s.sitegr1, x.cumdose, f.adas_bl, f.adas_post, f.cibic_post,
    c.comp8, c.comp16, c.comp24, m.mmsetot,
    ht.vsstresn as heightbl, wt.vsstresn as weightbl,
    v1.svstdtc as visit1dtc, rd.dsstdtc as randdtc,
    eot.dsdecod as eotdecod, eos.dsdecod as eosdecod, eos.dsstdtc as eosdtc,
    mh.mhstdtc as onsetdtc, sc.scstresn as educlvl
  from sdtm.dm as d
  left join sitegr as s on d.siteid = s.siteid
  left join dose as x on d.usubjid = x.usubjid
  left join eff as f on d.usubjid = f.usubjid
  left join comp as c on d.usubjid = c.usubjid
  left join mmse as m on d.usubjid = m.usubjid
  left join sdtm.vs(where=(vstestcd = 'HEIGHT' and visitnum = 1)) as ht on d.usubjid = ht.usubjid
  left join sdtm.vs(where=(vstestcd = 'WEIGHT' and visitnum = 3)) as wt on d.usubjid = wt.usubjid
  left join sdtm.sv(where=(visitnum = 1)) as v1 on d.usubjid = v1.usubjid
  left join sdtm.ds(where=(dsdecod = 'RANDOMIZED')) as rd on d.usubjid = rd.usubjid
  left join sdtm.ds(where=(dscat = 'DISPOSITION EVENT' and dsscat = 'STUDY TREATMENT')) as eot
    on d.usubjid = eot.usubjid
  left join sdtm.ds(where=(dscat = 'DISPOSITION EVENT' and dsscat = 'STUDY PARTICIPATION')) as eos
    on d.usubjid = eos.usubjid
  left join sdtm.mh(where=(mhcat = 'PRIMARY DIAGNOSIS')) as mh on d.usubjid = mh.usubjid
  left join sdtm.sc(where=(sctestcd = 'EDUYRNUM')) as sc on d.usubjid = sc.usubjid;
quit;

data adsl1;
  set adsl0;
  length trt01p trt01a agegr1 bmiblgr1 durdsgr1 ittfl saffl efffl comp8fl comp16fl comp24fl
    eotstt dctreas disconfl dsraefl eosstt dcsreas $200;

  trt01p = arm;
  trt01a = actarm;
  if trt01p ne '' then trt01pn = input(trt01p, trtn.);
  if trt01a ne '' then trt01an = input(trt01a, trtn.);

  %dt(rfxstdtc, trtsdt)
  /* 6 subjects have no final dose date; RFENDTC is their last visit */
  _edtc = coalescec(rfxendtc, rfendtc);
  %dt(_edtc, trtedt)
  if trtsdt ne . and trtedt ne . then trtdurd = trtedt - trtsdt + 1;
  if trtdurd > 0 then avgdd = cumdose / trtdurd;

  agegr1 = put(age, agegr.);
  agegr1n = input(put(age, agegrn.), 1.);
  racen = input(race, racen.);

  ittfl = ifc(armcd ne '', 'Y', 'N');
  saffl = ifc(ittfl = 'Y' and trtsdt ne ., 'Y', 'N');
  efffl = ifc(ittfl = 'Y' and adas_bl = 1 and adas_post = 1 and cibic_post = 1, 'Y', 'N');
  comp8fl = ifc(comp8 = 1, 'Y', 'N');
  comp16fl = ifc(comp16 = 1, 'Y', 'N');
  comp24fl = ifc(comp24 = 1, 'Y', 'N');

  %dt(dthdtc, dthdt)

  if heightbl > 0 and weightbl ne . then bmibl = weightbl / (heightbl / 100) ** 2;
  if bmibl ne . then bmiblgr1 = put(bmibl, bmigr.);

  %dt(visit1dtc, visit1dt)
  %dt(randdtc, randdt)

  /* partial onset date: first of the month or year */
  if length(onsetdtc) = 4 then onsetdtc = cats(onsetdtc, '-01-01');
  else if length(onsetdtc) = 7 then onsetdtc = cats(onsetdtc, '-01');
  %dt(onsetdtc, disonsdt)
  if visit1dt ne . and disonsdt ne . then durdis = (visit1dt - disonsdt + 1) / 30.4375;
  if durdis ne . then durdsgr1 = put(durdis, durgr.);

  if eotdecod ne '' then eotstt = ifc(eotdecod = 'COMPLETED', 'COMPLETED', 'DISCONTINUED');
  if eotstt = 'DISCONTINUED' then do;
    dctreas = eotdecod;
    disconfl = 'Y';
  end;
  if dctreas = 'ADVERSE EVENT' then dsraefl = 'Y';

  if eosdecod ne '' then eosstt = ifc(eosdecod = 'COMPLETED', 'COMPLETED', 'DISCONTINUED');
  if eosstt = 'DISCONTINUED' then dcsreas = eosdecod;
  %dt(eosdtc, eosdt)

  label
    studyid = 'Study Identifier'
    usubjid = 'Unique Subject Identifier'
    subjid = 'Subject Identifier for the Study'
    siteid = 'Study Site Identifier'
    sitegr1 = 'Pooled Site Group 1'
    arm = 'Description of Planned Arm'
    actarm = 'Description of Actual Arm'
    armnrs = 'Reason Arm and/or Actual Arm is Null'
    trt01p = 'Planned Treatment for Period 01'
    trt01pn = 'Planned Treatment for Period 01 (N)'
    trt01a = 'Actual Treatment for Period 01'
    trt01an = 'Actual Treatment for Period 01 (N)'
    trtsdt = 'Date of First Exposure to Treatment'
    trtedt = 'Date of Last Exposure to Treatment'
    trtdurd = 'Total Treatment Duration (Days)'
    cumdose = 'Cumulative Dose (mg)'
    avgdd = 'Average Daily Dose (mg)'
    age = 'Age'
    agegr1 = 'Pooled Age Group 1'
    agegr1n = 'Pooled Age Group 1 (N)'
    ageu = 'Age Units'
    sex = 'Sex'
    race = 'Race'
    racen = 'Race (N)'
    ethnic = 'Ethnicity'
    saffl = 'Safety Population Flag'
    ittfl = 'Intent-to-Treat Population Flag'
    efffl = 'Efficacy Population Flag'
    comp8fl = 'Completers of Week 8 Flag'
    comp16fl = 'Completers of Week 16 Flag'
    comp24fl = 'Completers of Week 24 Flag'
    disconfl = 'Discontinued from Treatment Flag'
    dsraefl = 'Discontinued Due to AE Flag'
    dthfl = 'Subject Death Flag'
    dthdt = 'Date of Death'
    heightbl = 'Baseline Height (cm)'
    weightbl = 'Baseline Weight (kg)'
    bmibl = 'Baseline BMI (kg/m2)'
    bmiblgr1 = 'Pooled Baseline BMI Group 1'
    visit1dt = 'Date of Visit 1'
    randdt = 'Date of Randomization'
    disonsdt = 'Date of Onset of Disease'
    durdis = 'Duration of Disease (Months)'
    durdsgr1 = 'Pooled Disease Duration Group 1'
    mmsetot = 'MMSE Total Score at Screening'
    educlvl = 'Years of Education'
    eotstt = 'End of Treatment Status'
    dctreas = 'Reason for Discontinuation of Treatment'
    eosstt = 'End of Study Status'
    eosdt = 'End of Study Date'
    dcsreas = 'Reason for Discontinuation from Study';
run;

%finalize(adsl1, adsl, Subject-Level Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SUBJID SITEID SITEGR1 ARM ACTARM ARMNRS TRT01P TRT01PN
    TRT01A TRT01AN TRTSDT TRTEDT TRTDURD CUMDOSE AVGDD AGE AGEGR1 AGEGR1N AGEU
    SEX RACE RACEN ETHNIC SAFFL ITTFL EFFFL COMP8FL COMP16FL COMP24FL DISCONFL
    DSRAEFL DTHFL DTHDT HEIGHTBL WEIGHTBL BMIBL BMIBLGR1 VISIT1DT RANDDT DISONSDT
    DURDIS DURDSGR1 MMSETOT EDUCLVL EOTSTT DCTREAS EOSSTT EOSDT DCSREAS,
  keys=STUDYID USUBJID)
