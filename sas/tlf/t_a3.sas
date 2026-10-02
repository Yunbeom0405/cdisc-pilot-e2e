/*******************************************************************************
Program : t_a3.sas
Purpose : Table A3 Treatment Emergent Adverse Events by Maximum Severity
*******************************************************************************/

%bign(trt01a, where=%str(saffl = 'Y'))

data te;
  set adam.adae(where=(trtemfl = 'Y' and saffl = 'Y'));
  col = input(put(trta, $trtcol.), 1.);
run;

/* worst severity per subject: overall (blank SOC) and within SOC */
proc sql;
  create table mx as
  select '' as aebodsys length=200, usubjid, col, max(aesevn) as sev
  from te group by usubjid, col
  union all
  select aebodsys, usubjid, col, max(aesevn)
  from te group by aebodsys, usubjid, col;

  create table soc as select distinct aebodsys from mx;
quit;

/* sev 0 = any severity */
data grid;
  set soc;
  do sev = 0 to 3;
    output;
  end;
run;

proc sql;
  create table cnt as
  select g.aebodsys, g.sev,
    sum(m.col = 1) as n_1, sum(m.col = 2) as n_2, sum(m.col = 3) as n_3
  from grid g left join mx m
    on g.aebodsys = m.aebodsys and (g.sev = 0 or g.sev = m.sev)
  group by g.aebodsys, g.sev
  order by g.aebodsys, g.sev;
quit;

data t_a3;
  set cnt;
  length label $200 c1-c3 $40;
  array n_{3};
  array c{3} c1-c3;
  array bign{3} _temporary_ (&n1 &n2 &n3);
  do i = 1 to 3;
    c{i} = %npct(sum(n_{i}, 0), bign{i}, d=1);
  end;
  if sev > 0 then label = scan('Mild|Moderate|Severe', sev, '|');
  else if aebodsys = '' then label = 'ANY TEAE';
  else label = aebodsys;
  indent = (sev > 0);
  row = _n_;
run;

%report(t_a3, t_a3, Table A3 Treatment Emergent Adverse Events by Maximum Severity,
  cols=c1 c2 c3,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3),
  foot1=Population: Safety. Treatment emergent: events which start on or after the first dose. Coded with MedDRA.,
  foot2=Cells: subjects (percent of N) by their worst severity within the body system.)
