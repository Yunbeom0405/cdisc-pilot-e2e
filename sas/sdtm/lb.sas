/*******************************************************************************
Program : lb.sas
Purpose : Create SDTM LB from the central lab transfer
*******************************************************************************/

/* vendor test code -> CDISC test (spec sheet LB Test Map) */
proc format;
  value $v_lbtestcd
    'CHEM002' = 'ALB'
    'CHEM003' = 'ALP'
    'CHEM004' = 'ALT'
    'CHEM005' = 'AST'
    'CHEM006' = 'BILI'
    'CHEM007' = 'UREAN'
    'CHEM008' = 'CA'
    'CHEM009' = 'CHOL'
    'CHEM010' = 'CK'
    'CHEM011' = 'CL'
    'CHEM012' = 'CREAT'
    'CHEM013' = 'GGT'
    'CHEM014' = 'GLUC'
    'CHEM015' = 'K'
    'CHEM016' = 'PHOS'
    'CHEM017' = 'PROT'
    'CHEM018' = 'SODIUM'
    'CHEM019' = 'URATE'
    'HEMA020' = 'ANISO'
    'HEMA021' = 'BASO'
    'HEMA022' = 'EOS'
    'HEMA023' = 'HCT'
    'HEMA024' = 'HGB'
    'HEMA025' = 'LYM'
    'HEMA026' = 'MACROCY'
    'HEMA027' = 'MCH'
    'HEMA028' = 'MCHC'
    'HEMA029' = 'MCV'
    'HEMA030' = 'MICROCY'
    'HEMA031' = 'MONO'
    'HEMA032' = 'PLAT'
    'HEMA033' = 'POIKILO'
    'HEMA034' = 'POLYCHR'
    'HEMA035' = 'RBC'
    'HEMA036' = 'WBC'
    'SPEC001' = 'HBA1CHGB'
    'SPEC037' = 'TSH'
    'SPEC038' = 'VITB12'
    'URIN039' = 'COLOR'
    'URIN040' = 'KETONES'
    'URIN041' = 'PH'
    'URIN042' = 'SPGRAV'
    'URIN043' = 'UROBIL';

  value $v_lbtest
    'CHEM002' = 'Albumin'
    'CHEM003' = 'Alkaline Phosphatase'
    'CHEM004' = 'Alanine Aminotransferase'
    'CHEM005' = 'Aspartate Aminotransferase'
    'CHEM006' = 'Bilirubin'
    'CHEM007' = 'Urea Nitrogen'
    'CHEM008' = 'Calcium'
    'CHEM009' = 'Cholesterol'
    'CHEM010' = 'Creatine Kinase'
    'CHEM011' = 'Chloride'
    'CHEM012' = 'Creatinine'
    'CHEM013' = 'Gamma Glutamyl Transferase'
    'CHEM014' = 'Glucose'
    'CHEM015' = 'Potassium'
    'CHEM016' = 'Phosphate'
    'CHEM017' = 'Protein'
    'CHEM018' = 'Sodium'
    'CHEM019' = 'Urate'
    'HEMA020' = 'Anisocytes'
    'HEMA021' = 'Basophils'
    'HEMA022' = 'Eosinophils'
    'HEMA023' = 'Hematocrit'
    'HEMA024' = 'Hemoglobin'
    'HEMA025' = 'Lymphocytes'
    'HEMA026' = 'Macrocytes'
    'HEMA027' = 'Ery. Mean Corpuscular Hemoglobin'
    'HEMA028' = 'Ery. Mean Corpuscular HGB Concentration'
    'HEMA029' = 'Ery. Mean Corpuscular Volume'
    'HEMA030' = 'Microcytes'
    'HEMA031' = 'Monocytes'
    'HEMA032' = 'Platelets'
    'HEMA033' = 'Poikilocytes'
    'HEMA034' = 'Polychromasia'
    'HEMA035' = 'Erythrocytes'
    'HEMA036' = 'Leukocytes'
    'SPEC001' = 'Hemoglobin A1C/Hemoglobin'
    'SPEC037' = 'Thyrotropin'
    'SPEC038' = 'Vitamin B12'
    'URIN039' = 'Color'
    'URIN040' = 'Ketones'
    'URIN041' = 'pH'
    'URIN042' = 'Specific Gravity'
    'URIN043' = 'Urobilinogen';

  value $v_lbcat
    'CHEM002' = 'CHEMISTRY'
    'CHEM003' = 'CHEMISTRY'
    'CHEM004' = 'CHEMISTRY'
    'CHEM005' = 'CHEMISTRY'
    'CHEM006' = 'CHEMISTRY'
    'CHEM007' = 'CHEMISTRY'
    'CHEM008' = 'CHEMISTRY'
    'CHEM009' = 'CHEMISTRY'
    'CHEM010' = 'CHEMISTRY'
    'CHEM011' = 'CHEMISTRY'
    'CHEM012' = 'CHEMISTRY'
    'CHEM013' = 'CHEMISTRY'
    'CHEM014' = 'CHEMISTRY'
    'CHEM015' = 'CHEMISTRY'
    'CHEM016' = 'CHEMISTRY'
    'CHEM017' = 'CHEMISTRY'
    'CHEM018' = 'CHEMISTRY'
    'CHEM019' = 'CHEMISTRY'
    'HEMA020' = 'HEMATOLOGY'
    'HEMA021' = 'HEMATOLOGY'
    'HEMA022' = 'HEMATOLOGY'
    'HEMA023' = 'HEMATOLOGY'
    'HEMA024' = 'HEMATOLOGY'
    'HEMA025' = 'HEMATOLOGY'
    'HEMA026' = 'HEMATOLOGY'
    'HEMA027' = 'HEMATOLOGY'
    'HEMA028' = 'HEMATOLOGY'
    'HEMA029' = 'HEMATOLOGY'
    'HEMA030' = 'HEMATOLOGY'
    'HEMA031' = 'HEMATOLOGY'
    'HEMA032' = 'HEMATOLOGY'
    'HEMA033' = 'HEMATOLOGY'
    'HEMA034' = 'HEMATOLOGY'
    'HEMA035' = 'HEMATOLOGY'
    'HEMA036' = 'HEMATOLOGY'
    'SPEC001' = 'CHEMISTRY'
    'SPEC037' = 'OTHER'
    'SPEC038' = 'OTHER'
    'URIN039' = 'URINALYSIS'
    'URIN040' = 'URINALYSIS'
    'URIN041' = 'URINALYSIS'
    'URIN042' = 'URINALYSIS'
    'URIN043' = 'URINALYSIS';

  value $nrind
    'N' = 'NORMAL'
    'L' = 'LOW'
    'H' = 'HIGH'
    'A' = 'ABNORMAL'
    other = ' ';

  invalue reqvn
    'SCRN' = 1
    'BASE' = 3
    'WK02-1D' = 3.5
    'WK02' = 4
    'WK04' = 5
    'WK04+1D' = 6
    'WK06' = 7
    'WK08' = 8
    'WK12' = 9
    'WK16' = 10
    'WK20' = 11
    'WK24' = 12
    'WK26' = 13
    'RETR' = 201
    other = .;
run;

data lb0;
  set raw_lab_results(where=(status = 'FINAL'));   /* cancelled results have a FINAL replacement */
  length usubjid lbtestcd lbtest lbcat lbnrind $200;
  usubjid = cats('01-', substr(patient_id, 1, 3), '-', substr(patient_id, 4));
  lbtestcd = put(test_code, $v_lbtestcd.);
  lbtest = put(test_code, $v_lbtest.);
  lbcat = put(test_code, $v_lbcat.);
  lbnrind = put(abn_flag, $nrind.);
  _reqvn = input(req_visit, ?? reqvn.);
  _d = substr(collection_dt, 1, 10);
run;

proc sql;
  create table lbv0 as
  select distinct usubjid, req_visit, _reqvn, _d
  from lb0;

  /* 1: requisition visit exists in SV */
  create table lbv1 as
  select a.*, b.visitnum as _vn1
  from lbv0 as a
  left join (select distinct usubjid, visitnum from sdtm.svmap) as b
    on a.usubjid = b.usubjid and a._reqvn = b.visitnum;

  /* 2: SV visit on the collection date, unscheduled first */
  create table lbv2 as
  select a.*, b.visitnum as _vn2, b.svpresp as _presp
  from lbv1 as a
  left join sdtm.svmap as b on a.usubjid = b.usubjid and a._d = b.svstdtc
  order by usubjid, req_visit, _d, _presp, _vn2;

  /* 3: previous planned visit, base of a new unscheduled number */
  create table lbv3 as
  select a.usubjid, a.req_visit, a._d, b.svstdtc as _bdt, b.visitnum as _base
  from lbv0 as a
  left join sdtm.svmap(where=(svpresp = 'Y')) as b
    on a.usubjid = b.usubjid and b.svstdtc < a._d
  order by usubjid, req_visit, _d, _bdt, _base;
quit;

data lbv2;
  set lbv2;
  by usubjid req_visit _d;
  if first._d;
run;

data lbv3;
  set lbv3;
  by usubjid req_visit _d;
  if last._d;
  _base = coalesce(_base, 0);
run;

data lbv4;
  merge lbv2 lbv3(keep=usubjid req_visit _d _base);
  by usubjid req_visit _d;
  if not missing(_vn1) then visitnum = _vn1;
  else if not missing(_vn2) then visitnum = _vn2;
  else _new = 1;
run;

/* new unscheduled visit: base + .1, .2 */
proc sort data=lbv4;
  by usubjid _new _base _d;
run;

data lbv4;
  set lbv4;
  by usubjid _new _base;
  length visit $200;
  if _new then do;
    if first._base then _n = 0;
    _n + 1;
    visitnum = round(_base + _n / 10, 0.01);
    visit = catx(' ', 'UNSCHEDULED', put(visitnum, best.));
  end;
run;

proc sql;
  create table lb1 as
  select l.*, v.visitnum, coalesce(v.visit, s.visit) as visit length=200, s.visitdy,
    d.rfstdtc, d.rfxstdtc, d.rfxendtc
  from lb0 as l
  left join lbv4 as v
    on l.usubjid = v.usubjid and l.req_visit = v.req_visit and l._d = v._d
  left join (select distinct usubjid, visitnum, visit, visitdy from sdtm.svmap) as s
    on v.usubjid = s.usubjid and v.visitnum = s.visitnum and v._new ne 1
  left join sdtm.dm as d on l.usubjid = d.usubjid;
quit;

data lb2;
  set lb1;
  length studyid domain lbrefid lborres lborresu lbornrlo lbornrhi lbstresc lbstresu
    epoch lbdtc $200;
  studyid = 'CDISCPILOT01';
  domain = 'LB';
  lbrefid = accession;
  lborres = result;
  lborresu = units;
  lbornrlo = ref_low;
  lbornrhi = ref_high;
  lbstresc = result_si;
  lbstresn = input(result_si, ?? best.);   /* '<0.2' and text stay null */
  lbstresu = units_si;
  lbstnrlo = input(ref_low_si, best.);
  lbstnrhi = input(ref_high_si, best.);
  lbdtc = collection_dt;

  %predose(lbdtc)
  %fepoch(lbdtc)
  %dy(lbdtc, lbdy)
  _row = _n_;
run;

%lobxfl(lb2, lblobxfl, by=lbtestcd, res=lborres, dtc=lbdtc)

proc sort data=lb2;
  by usubjid lbcat lbtestcd lbdtc;
run;

data lb3;
  set lb2;
  by usubjid;
  if first.usubjid then lbseq = 0;
  lbseq + 1;

  label
    studyid = 'Study Identifier'
    domain = 'Domain Abbreviation'
    usubjid = 'Unique Subject Identifier'
    lbseq = 'Sequence Number'
    lbrefid = 'Specimen ID'
    lbtestcd = 'Lab Test or Examination Short Name'
    lbtest = 'Lab Test or Examination Name'
    lbcat = 'Category for Lab Test'
    lborres = 'Result or Finding in Original Units'
    lborresu = 'Original Units'
    lbornrlo = 'Reference Range Lower Limit in Orig Unit'
    lbornrhi = 'Reference Range Upper Limit in Orig Unit'
    lbstresc = 'Character Result/Finding in Std Format'
    lbstresn = 'Numeric Result/Finding in Standard Units'
    lbstresu = 'Standard Units'
    lbstnrlo = 'Reference Range Lower Limit-Std Units'
    lbstnrhi = 'Reference Range Upper Limit-Std Units'
    lbnrind = 'Reference Range Indicator'
    lblobxfl = 'Last Observation Before Exposure Flag'
    visitnum = 'Visit Number'
    visit = 'Visit Name'
    visitdy = 'Planned Study Day of Visit'
    epoch = 'Epoch'
    lbdtc = 'Date/Time of Specimen Collection'
    lbdy = 'Study Day of Specimen Collection';
run;

%finalize(lb3, lb, Laboratory Test Results,
  vars=STUDYID DOMAIN USUBJID LBSEQ LBREFID LBTESTCD LBTEST LBCAT LBORRES LBORRESU
    LBORNRLO LBORNRHI LBSTRESC LBSTRESN LBSTRESU LBSTNRLO LBSTNRHI LBNRIND LBLOBXFL
    VISITNUM VISIT VISITDY EPOCH LBDTC LBDY,
  keys=STUDYID USUBJID LBCAT LBTESTCD LBDTC)
