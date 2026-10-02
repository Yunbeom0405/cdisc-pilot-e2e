/*******************************************************************************
Program : t_14_1_01.sas
Purpose : Table 14-1.01 Summary of Populations
*******************************************************************************/

%bign(trt01p, where=%str(ittfl = 'Y'))

data pop;
  set adam.adsl(where=(ittfl = 'Y'));
  col = input(put(trt01p, $trtcol.), 1.);
  output;
  col = 4;
  output;
run;

proc sql;
  create table cnt as
  select col,
    sum(ittfl = 'Y') as r1, sum(saffl = 'Y') as r2, sum(efffl = 'Y') as r3,
    sum(comp24fl = 'Y') as r4, sum(eotstt = 'COMPLETED') as r5, sum(eosstt = 'COMPLETED') as r6
  from pop
  group by col;
quit;

proc transpose data=cnt out=cnt2(rename=(_name_=stat)) prefix=n;
  id col;
run;

data t_14_1_01;
  set cnt2;
  length label $200 c1-c4 $40;
  array n{4} n1-n4;
  array c{4} c1-c4;
  array bign{4} _temporary_ (&n1 &n2 &n3 &n4);
  row = input(compress(stat, , 'kd'), best.);
  indent = 0;
  label = choosec(row, 'Intent-To-Treat (ITT)', 'Safety', 'Efficacy', 'Completed Week 24',
    'Completed Treatment', 'Completed Study');
  do i = 1 to 4;
    c{i} = %npct(n{i}, bign{i});
  end;
  keep row indent label c1-c4;
run;

%report(t_14_1_01, t_14_1_01, Table 14-1.01 Summary of Populations,
  cols=c1 c2 c3 c4,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3)#Total|(N=&n4),
  foot1=Population: Intent-to-Treat. Percentages use N in the column header.,
  foot2=Completed Treatment: EOTSTT = COMPLETED. Completed Study: EOSSTT = COMPLETED.)
