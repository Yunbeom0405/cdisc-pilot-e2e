/*******************************************************************************
Program : admh.sas
Purpose : Create ADaM ADMH
*******************************************************************************/

data mh0;
  set sdtm.mh(keep=studyid usubjid mhseq mhterm mhdecod mhbodsys mhcat mhstdtc mhendtc);
run;

%addadsl(mh0, mh1, SITEID TRT01P TRT01PN AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL ITTFL)

data admh1;
  set mh1(rename=(trt01p=trtp trt01pn=trtpn));
  label
    trtp = 'Planned Treatment'
    trtpn = 'Planned Treatment (N)';
run;

/* the primary diagnosis is not coded */
%first(admh1, aoccsfl, by=usubjid mhbodsys, order=mhseq, key=usubjid mhseq,
  where=mhcat ne 'PRIMARY DIAGNOSIS')
%first(admh1, aoccpfl, by=usubjid mhbodsys mhdecod, order=mhseq, key=usubjid mhseq,
  where=mhcat ne 'PRIMARY DIAGNOSIS')

data admh1;
  set admh1;
  label
    aoccpfl = '1st Occurrence of Preferred Term Flag'
    aoccsfl = '1st Occurrence of SOC Flag';
run;

%finalize(admh1, admh, Medical History Analysis Dataset, lib=adam,
  vars=STUDYID USUBJID SITEID TRTP TRTPN AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL
    ITTFL MHSEQ MHTERM MHDECOD MHBODSYS MHCAT MHSTDTC MHENDTC AOCCPFL AOCCSFL,
  keys=STUDYID USUBJID MHSEQ)
