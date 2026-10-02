/*******************************************************************************
Program : t_14_5_01.sas
Purpose : Table 14-5.01 Incidence of Treatment Emergent Adverse Events by Treatment Group
*******************************************************************************/

%bign(saffl = 'Y', trt01a)

data te;
  set adam.adae(where=(trtemfl = 'Y' and saffl = 'Y'));
  col = input(put(trta, $trtcol.), 1.);
run;

/* subjects and events: any event, by SOC, by SOC and PT */
proc sql;
  create table cnt as
  select 0 as lvl, '' as aebodsys length=200, '' as aedecod length=200, col,
    count(distinct usubjid) as n, count(*) as ev
  from te group by col
  union all
  select 1, aebodsys, '', col, count(distinct usubjid), count(*)
  from te group by aebodsys, col
  union all
  select 2, aebodsys, aedecod, col, count(distinct usubjid), count(*)
  from te group by aebodsys, aedecod, col;
quit;

proc sort data=cnt;
  by lvl aebodsys aedecod col;
run;

data rows;
  set cnt;
  by lvl aebodsys aedecod;
  array n_{3};
  array ev_{3};
  retain n_: ev_:;
  if first.aedecod then call missing(of n_{*}, of ev_{*});
  n_{col} = n;
  ev_{col} = ev;
  if last.aedecod then do;
    do i = 1 to 3;
      n_{i} = sum(n_{i}, 0);
      ev_{i} = sum(ev_{i}, 0);
    end;
    tot = sum(of n_{*});
    output;
  end;
  keep lvl aebodsys aedecod n_: ev_: tot;
run;

/* Fisher's exact test, two-sided: sum of tables as likely or less likely than observed */
%macro fisher(x1, m1, x2, m2, p);
  _k = &x1 + &x2;
  _nn = &m1 + &m2;
  _obs = pdf('hyper', &x1, _nn, _k, &m1);
  &p = 0;
  do _x = max(0, _k - &m2) to min(_k, &m1);
    _px = pdf('hyper', _x, _nn, _k, &m1);
    if _px <= _obs * (1 + 1e-7) then &p = &p + _px;
  end;
  &p = min(&p, 1);
%mend fisher;

data rows;
  set rows;
  length label c1-c5 $40;
  array n_{3};
  array ev_{3};
  array c{5} c1-c5;
  array bign{3} _temporary_ (&n1 &n2 &n3);
  label = coalescec(aedecod, aebodsys, 'ANY BODY SYSTEM');
  do i = 1 to 3;
    c{i} = ifc(n_{i} = 0, '0', cat(%npct(n_{i}, bign{i}, d=1), ' [', cats(ev_{i}), ']'));
  end;
  %fisher(n_1, &n1, n_2, &n2, p_low)
  %fisher(n_1, &n1, n_3, &n3, p_high)
  c4 = %pv(p_low);
  c5 = %pv(p_high);
  indent = (lvl = 2);
run;

/* any event first; SOC alphabetical; PT by descending number of subjects, then alphabetical */
data rows;
  set rows;
  _any = (lvl > 0);
  _ptord = ifn(lvl = 2, -tot, 0);
run;

proc sort data=rows;
  by _any aebodsys lvl _ptord aedecod;
run;

data t_14_5_01;
  set rows;
  row = _n_;
run;

%report(t_14_5_01, t_14_5_01, Table 14-5.01 Incidence of Treatment Emergent Adverse Events by Treatment Group,
  cols=c1 c2 c3 c4 c5,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3)#p-value|Placebo vs.|Low Dose#p-value|Placebo vs.|High Dose,
  foot1=Population: Safety. Treatment emergent: events which start on or after the first dose. Coded with MedDRA.,
  foot2=Cells: subjects with at least one event (percent of N) [number of events]. p-values: two-sided Fisher exact test.)
