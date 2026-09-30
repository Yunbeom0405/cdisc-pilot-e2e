/*******************************************************************************
Program : dm.sas
Purpose : Create SDTM DM
*******************************************************************************/

proc sql;
  create table ex_subj as
  select subject,
    max(case when folder = 'V3' then visit_date else '' end) as v3_date,
    max(patch25_per_day = '1') as any25
  from raw_ex_dosage
  group by subject;
quit;

/* all contact dates for RFPENDTC */
data contact;
  set raw_visits(keep=subject visit_date)
    raw_ds_summary(keep=subject visit_date)
    raw_ae(keep=subject recorded_date rename=(recorded_date=visit_date));
  cdate = input(compress(visit_date), date9.);
run;

proc sql;
  create table dm0 as
  select d.*, i.subject_status, i.treatment_arm, i.screen_fail_datetime,
    e.v3_date, f.final_dose_date as last_dose, e.any25, (e.subject is not missing) as has_ex,
    s.visit_date as ds_date, s.death_date, c.last_contact
  from raw_dm as d
  left join raw_irt_randomization as i on d.subject = catx('-', i.site_id, i.subject_id)
  left join ex_subj as e on d.subject = e.subject
  left join raw_final_dose as f on d.subject = f.subject
  left join raw_ds_summary as s on d.subject = s.subject
  left join (select subject, max(cdate) as last_contact from contact group by subject) as c
    on d.subject = c.subject;
quit;

data dm1;
  set dm0;
  length studyid domain usubjid subjid rfstdtc rfendtc rfxstdtc rfxendtc rficdtc
    rfpendtc dthdtc dthfl siteid brthdtc ageu race ethnic armcd arm
    actarmcd actarm armnrs country dmdtc $200;

  studyid = 'CDISCPILOT01';
  domain = 'DM';
  usubjid = cats('01-', subject);
  subjid = scan(subject, 2, '-');
  siteid = site;
  country = 'USA';

  %iso(v3_date, rfxstdtc)
  %iso(last_dose, rfxendtc)
  rfstdtc = rfxstdtc;
  %iso(ds_date, rfendtc)
  %iso(consent_date, rficdtc)
  if not missing(screen_fail_datetime) then
    last_contact = max(last_contact, input(substr(screen_fail_datetime, 1, 10), e8601da.));
  rfpendtc = put(last_contact, e8601da.);

  %iso(death_date, dthdtc)
  if not missing(dthdtc) then dthfl = 'Y';

  /* year-only birth date: 01JUL used for AGE only */
  %iso(birth_date, brthdtc)
  if length(brthdtc) = 4 then brthdt = mdy(7, 1, input(brthdtc, 4.));
  else brthdt = input(brthdtc, e8601da.);
  age = floor(yrdif(brthdt, input(rficdtc, e8601da.), 'AGE'));
  if not missing(age) then ageu = 'YEARS';

  select (origin);
    when ('CA', 'HP') race = 'WHITE';
    when ('AF') race = 'BLACK OR AFRICAN AMERICAN';
    when ('EA', 'AS') race = 'ASIAN';
    when ('O') race = 'OTHER';
  end;
  ethnic = ifc(origin = 'HP', 'HISPANIC OR LATINO', 'NOT HISPANIC OR LATINO');

  if subject_status = 'Screen Failed' then armnrs = 'SCREEN FAILURE';
  else do;
    arm = treatment_arm;
    select (arm);
      when ('Placebo') armcd = 'Pbo';
      when ('Xanomeline Low Dose') armcd = 'Xan_Lo';
      when ('Xanomeline High Dose') armcd = 'Xan_Hi';
    end;

    if has_ex then do;
      actarmcd = armcd;
      actarm = arm;
      /* high dose subjects never given the 25 cm2 patch got low dose only */
      if armcd = 'Xan_Hi' and not any25 then do;
        actarmcd = 'Xan_Lo';
        actarm = 'Xanomeline Low Dose';
      end;
    end;
    else armnrs = 'ASSIGNED, NOT TREATED';
  end;

  %iso(visit_date, dmdtc)
  %dy(dmdtc, dmdy)

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    subjid = 'Subject Identifier for the Study'
    rfstdtc = 'Subject Reference Start Date/Time'
    rfendtc = 'Subject Reference End Date/Time'
    rfxstdtc = 'Date/Time of First Study Treatment'
    rfxendtc = 'Date/Time of Last Study Treatment'
    rficdtc = 'Date/Time of Informed Consent'
    rfpendtc = 'Date/Time of End of Participation'
    dthdtc = 'Date/Time of Death'
    dthfl = 'Subject Death Flag'
    siteid = 'Study Site Identifier'
    brthdtc = 'Date/Time of Birth'
    age = 'Age'
    ageu = 'Age Units'
    sex = 'Sex'
    race = 'Race'
    ethnic = 'Ethnicity'
    armcd = 'Planned Arm Code'
    arm = 'Description of Planned Arm'
    actarmcd = 'Actual Arm Code'
    actarm = 'Description of Actual Arm'
    armnrs = 'Reason Arm and/or Actual Arm is Null'
    country = 'Country'
    dmdtc = 'Date/Time of Collection'
    dmdy = 'Study Day of Collection';
run;

%finalize(dm1, dm, Demographics,
  vars=STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC
    RFPENDTC DTHDTC DTHFL SITEID BRTHDTC AGE AGEU SEX RACE ETHNIC ARMCD ARM
    ACTARMCD ACTARM ARMNRS COUNTRY DMDTC DMDY,
  keys=STUDYID USUBJID)
