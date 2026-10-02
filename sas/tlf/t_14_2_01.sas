/*******************************************************************************
Program : t_14_2_01.sas
Purpose : Table 14-2.01 Summary of Demographic and Baseline Characteristics
*******************************************************************************/

%bign(trt01p, where=%str(ittfl = 'Y'))

data pop;
  set adam.adsl(where=(ittfl = 'Y'));
  col = input(put(trt01p, $trtcol.), 1.);
  output;
  col = 4;
  output;
run;

proc datasets lib=work nolist;
  delete long;
quit;

/* section header row */
%macro head(sec, title);
  data _l;
    length label $200 val $40;
    sec = &sec;
    ord = 0;
    label = "&title";
    col = 1;
    val = '';
  run;

  proc append base=long data=_l;
  run;
%mend head;

%macro cont(sec, var, title);
  %head(&sec, &title)

  proc means data=pop noprint nway;
    class col;
    var &var;
    output out=_s n=n mean=mean std=sd median=med min=min max=max;
  run;

  data _l;
    set _s;
    length label $200 val $40;
    sec = &sec;
    ord = 1; label = 'n'; val = cats(n); output;
    ord = 2; label = 'Mean'; val = %f(mean, 1); output;
    ord = 3; label = 'SD'; val = %f(sd, 2); output;
    ord = 4; label = 'Median'; val = %f(med, 1); output;
    ord = 5; label = 'Min'; val = %f(min, 1); output;
    ord = 6; label = 'Max'; val = %f(max, 1); output;
    keep sec ord label col val;
  run;

  proc append base=long data=_l;
  run;
%mend cont;

/* categories in &values (#-separated), shown as &labels */
%macro cat(sec, var, title, values, labels=&values);
  %if &title ne %then %head(&sec, &title);

  proc sql;
    create table _c as
    select col, &var as v length=200, count(*) as n
    from pop
    group by col, &var;
  quit;

  data _l;
    if 0 then set _c;
    if _n_ = 1 then do;
      declare hash h(dataset: '_c');
      h.definekey('col', 'v');
      h.definedata('n');
      h.definedone();
    end;
    length label $200 val $40 v $200;
    array bign{4} _temporary_ (&n1 &n2 &n3 &n4);
    sec = &sec;
    do ord = 11 to 10 + countw("&values", '#');
      v = scan("&values", ord - 10, '#');
      label = scan("&labels", ord - 10, '#');
      do col = 1 to 4;
        if h.find() ne 0 then n = 0;
        val = %npct(n, bign{col});
        output;
      end;
    end;
    stop;
    keep sec ord label col val;
  run;

  proc append base=long data=_l;
  run;
%mend cat;

%cont(1, age, Age (y))
%cat(1, agegr1, , <65#65-80#>80)
%cat(2, sex, Sex, M#F, labels=Male#Female)
%cat(3, race, Race, WHITE#BLACK OR AFRICAN AMERICAN#ASIAN#OTHER)
%cat(4, ethnic, Ethnicity, HISPANIC OR LATINO#NOT HISPANIC OR LATINO)
%cont(5, mmsetot, MMSE Total Score)
%cont(6, durdis, Duration of Disease (Months))
%cat(6, durdsgr1, , %str(<12#>=12))
%cont(7, educlvl, Years of Education)
%cont(8, weightbl, Baseline Weight (kg))
%cont(9, heightbl, Baseline Height (cm))
%cont(10, bmibl, Baseline BMI (kg/m2))
%cat(10, bmiblgr1, , %str(<25#25-<30#>=30))

proc sort data=long;
  by sec ord label col;
run;

proc transpose data=long out=t_14_2_01(drop=_name_) prefix=c;
  by sec ord label;
  id col;
  var val;
run;

data t_14_2_01;
  set t_14_2_01;
  row = _n_;
  indent = (ord > 0);
run;

%report(t_14_2_01, t_14_2_01, Table 14-2.01 Summary of Demographic and Baseline Characteristics,
  cols=c1 c2 c3 c4,
  heads=Placebo|(N=&n1)#Xanomeline|Low Dose|(N=&n2)#Xanomeline|High Dose|(N=&n3)#Total|(N=&n4),
  foot1=Population: Intent-to-Treat. Percentages use N in the column header.,
  foot2=Duration of disease: months from onset of Alzheimer%str(%')s disease to Visit 1.)
