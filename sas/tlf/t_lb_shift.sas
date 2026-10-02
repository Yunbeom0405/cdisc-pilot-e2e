/*******************************************************************************
Program : t_lb_shift.sas
Purpose : Table 23 Shifts in Laboratory Chemistry Values, Baseline to On-treatment
*******************************************************************************/

%bign(trt01a, where=%str(saffl = 'Y'))

data lb;
  set adam.adlbc(where=(ontrtfl = 'Y' and saffl = 'Y' and not missing(bnrind) and not missing(anrind)));
  col = input(put(trta, $trtcol.), 1.);
run;

data shifts;
  length txt $20 bnrind anrind $6;
  seq = 0; txt = 'N'; output;
  seq = 1; txt = 'Normal to Low'; bnrind = 'NORMAL'; anrind = 'LOW'; output;
  seq = 2; txt = 'Normal to High'; bnrind = 'NORMAL'; anrind = 'HIGH'; output;
  seq = 3; txt = 'Low to Normal'; bnrind = 'LOW'; anrind = 'NORMAL'; output;
  seq = 4; txt = 'Low to High'; bnrind = 'LOW'; anrind = 'HIGH'; output;
  seq = 5; txt = 'High to Normal'; bnrind = 'HIGH'; anrind = 'NORMAL'; output;
  seq = 6; txt = 'High to Low'; bnrind = 'HIGH'; anrind = 'LOW'; output;
run;

/* subjects with at least one on-treatment value in the shift category; seq 0 = all evaluable */
proc sql;
  create table cnt as
  select p.paramcd, p.param, s.seq, s.txt,
    count(distinct case when l.col = 1 then l.usubjid end) as n_1,
    count(distinct case when l.col = 2 then l.usubjid end) as n_2,
    count(distinct case when l.col = 3 then l.usubjid end) as n_3
  from (select distinct paramcd, param from lb) p
    cross join shifts s
    left join lb l
    on p.paramcd = l.paramcd and (s.seq = 0 or (s.bnrind = l.bnrind and s.anrind = l.anrind))
  group by p.paramcd, p.param, s.seq, s.txt
  order by p.paramcd, s.seq;
quit;

data t_lb_shift;
  set cnt;
  by paramcd;
  length label $200 c1-c3 $40;
  array n_{3};
  array c{3} c1-c3;
  array d{3} _temporary_;
  if first.paramcd then do;
    label = param;
    indent = 0;
    do i = 1 to 3;
      d{i} = n_{i};
      c{i} = '';
    end;
    row + 1;
    output;
  end;
  label = txt;
  indent = 1;
  do i = 1 to 3;
    c{i} = ifc(seq = 0, cats(n_{i}), %npct(n_{i}, d{i}, d=1));
  end;
  row + 1;
  output;
run;

%report(t_lb_shift, t_lb_shift, Table 23 Shifts in Laboratory Chemistry Values from Baseline to On-treatment,
  cols=c1 c2 c3,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3),
  foot1=Population: Safety. N: subjects with a baseline and at least one on-treatment value. Range category (low/normal/high) from the reference range.,
  foot2=Cells: subjects (percent of N) with at least one on-treatment value in the category; a subject can be in more than one shift.)
