/* Disclaimer
Copyright (C), Sotirios Adamakis
This software may be used, copied, or redistributed only with the permission of Sotirios Adamakis. 
If used, copied, or redistributed it should not be sold and this copyright notice should be reproduced 
on each copy made. All code in this document is provided "as is" by Sotirios Adamakis without warranty 
of any kind, either express or implied, including but not limited to the implied warranties of 
merchantability and fitness for a particular purpose. Recipients acknowledge and agree that 
Sotirios Adamakis shall not be liable for any damages whatsoever arising out of their use of this 
material. In addition, Sotirios Adamakis will provide no support, updates or patches for the materials contained herein.
*/
/*------------------------------------------------------------------------------------------------------*/
/* Author:                   ---  Sotirios Adamakis                                                     */
/* Program Name:             ---  gini_core_macro.sas	           								*/
/* Description:              ---  Part of Gini calculation macros   									*/
/** Parameters:                                             */ 
/**   indata: the input dataset                             */
/**     type: LIN or LINEAR for linear models               */
/**           LOG or LOGIT for logit models                 */
/**       wt: the weight variable                           */
/**           1 or leave blank for no weight                */
/**    score: the score (independent, predict) variable     */
/**     yvar: the Y (depedent, outcome, target) variable    */
/**removemissing: Y to remove obseravtions with missing     */
/**               score or yvar                             */
/**   giniout: the output dataset contains statistics       */
/** sortorder: leave blank for ascending                    */
/**            descending for descending (default)          */
/**     title: the title of output                          */
/**     print: Y to print output (default)                  */
/**            N to hidden output                           */
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/

%macro gini_core_macro(indata =,
                     label =,
                      type =LOGIT,
                     score =,
                        wt =,
                      yvar =,
                   giniout =giniout,
                 sortorder =descending,
                     title =,
                     print =N
            );

%if  "&wt" eq "1" %then %let wt=;
*** get nb obs and missing;
proc summary data=&indata noprint;
  var &score &yvar ;
  output out=_tmp_tab0 nmiss=score_miss y_miss;
run;
data _null_;
  set _tmp_tab0;
  call symput("tot",        compress(put(_FREQ_,best12.)));
  call symput("score_miss", compress(put(score_miss,best12.)));
  call symput("y_miss",     compress(put(y_miss,best12.)));
run;

*** sort the data by score;
proc sort data=&indata(keep=&score &yvar &wt 
      where=(&score ne . and &yvar ne .) ) out=_temp_indata_gini;
  by &sortorder &score;
run;

*** capture the summary;
proc summary data=_temp_indata_gini noprint;
var &score &yvar ;
%if "&wt" ne ""  %then weight &wt;;
output out=_tmp_tab
       mean=score_mean y_mean 
       sum =score_sum  y_sum  
       n   =n y_count
       %if "&wt" ne ""  %then SUMWGT=wtncounts y_wcount;
;
run;

data _null_;
  set _tmp_tab;
  call symput("ntot",    compress(put(n,best12.)));
  %if "&wt" ne ""  %then %do;
     call symput("wtot", compress(put(wtncounts,best12.)));
  %end;
  %else %do;
     call symput("wtot", compress(put(n,best12.)));
     y_wcount=y_count;
  %end;
  call symput("ymean",   compress(put(y_mean,best12.)));
  call symput("smean",   compress(put(score_mean,best12.)));
  call symput("ysum",    compress(put(y_sum,best12.)));
  call symput("goodsum", compress(put(y_wcount-y_sum,best12.)));
  call symput("n_miss",  compress(put(&tot-n,best12.)));
run;

%let _wt=;
%if "&wt" ne "" %then %let _wt=%bquote(*&wt);

/*Calculate GINI and KS of the score */
data _gini0;
  length dataname $41.;
  set _temp_indata_gini end=last;
  by &sortorder &score;
  retain sum_recov sum_good sum_target Obs gini ks ssr sst 0;
  sum_recov=sum(sum_recov,    &yvar  &_wt  );
  Obs=sum(Obs,1 &_wt);
  if &ysum>0 and &wtot>0 then do;
   cum_pct_recov = (sum_recov/&ysum);
   cum_pct_accts = (Obs/&wtot);
   %if %upcase(&type) eq LOG or %upcase(&type) eq LOGIT %then %do;
     sum_good=sum(sum_good,  (1-&yvar)  &_wt  );;
     if &goodsum ne 0 then cum_pct_good = sum_good / &goodsum; else cum_pct_good=.;
     gini=sum(gini,2*((cum_pct_recov-cum_pct_good)*((1 &_wt)/&wtot)));
     ks=max(ks,(cum_pct_recov-cum_pct_good));    
   %end;
   %if %upcase(&type) eq LIN or %upcase(&type) eq LINEAR %then %do;
     gini=sum(gini,2*((cum_pct_recov-cum_pct_accts)*((1 &_wt)/&wtot)));
     ks=max(ks,(cum_pct_recov-cum_pct_accts));
     ssr=sum(ssr,(&score -&ymean)**2 &_wt);
     sst=sum(sst,(&yvar  -&ymean)**2 &_wt);
     **R2=ssr/sst;
   %end;
  end;
  else do;
    gini=.;
    ks=.;
  end;
  if last then do;
    DataName="&label";
    &yvar=&ymean;
    &score=&smean;
    &yvar._miss=&y_miss;
    &score._miss=&score_miss;
    wtot=&wtot;
    tot=&tot;
    ntot=&ntot;
    n_miss=&tot-&ntot;
    label &yvar="Mean of Outcome(&yvar)";
    label &score="Mean of Score(&score)";
    label &yvar._miss="Nb of Missing in Outcome(&yvar)";
    label &score._miss="Nb of Missing in Score(&score)";
    label wtot="Weighted Total";
    label tot="Total Records";
    label ntot="Total Non-missing Records";
    label n_miss="Total Records without missing";
    output;
  end;
run;

/*Calculate perfect GINI and KS: use dependent variable itself to predict */
%if %upcase(&type) eq LOG or %upcase(&type) eq LOGIT %then %do;
  data _gini1;
    opt_gini=1;
    opt_ks=1;
  run;
%end;
%if %upcase(&type) eq LIN or %upcase(&type) eq LINEAR %then %do;
proc sort data=_temp_indata_gini;
  by descending &yvar;
run;
data _gini1;
  set _temp_indata_gini end=last;
  by descending &yvar ;
  retain sum_recov sum_good Obs opt_gini opt_ks 0;
  sum_recov=sum(sum_recov,    &yvar  &_wt  );
  Obs=sum(Obs,1 &_wt);
  if &ysum>0 then cum_pct_recov = (sum_recov/&ysum);else cum_pct_recov=.;
  if &wtot>0 then cum_pct_accts = (Obs/&wtot);else cum_pct_accts =.;
  if &wtot>0 then opt_gini=sum(opt_gini,2*((cum_pct_recov-cum_pct_accts)*((1 &_wt)/&wtot)));else opt_gini=.;
  opt_ks=max(opt_ks,(cum_pct_recov-cum_pct_accts));
  if last then do;
    keep opt_gini opt_ks;
    output;
  end;
run;
%end;

data &giniout;
  merge _gini0 _gini1;
  gini_ind=gini;
  if opt_gini>0 then lift_ratio=gini/opt_gini; else lift_ratio=.;
run;

%if %upcase(&print) eq YES or %upcase(&print) eq Y %then %do;
  %if "&title" eq "" %then title3 "Gini for &score against &yvar on &indata";
                     %else title3 "&title";
   ;
  %if &tot-&ntot>0   %then %do;
     %let n_rate1=%sysfunc(putn(%sysevalf(&n_miss/&tot),percent8.2));
     %let n_rate2=%sysfunc(putn(%sysevalf(&score_miss/&tot),percent8.2));
     %let n_rate3=%sysfunc(putn(%sysevalf(&y_miss/&tot),percent8.2));
     title2 "Missing values found. Total= &tot N_miss= &n_miss (&n_rate1)";
     title3 "Score_miss= &score_miss (&n_rate2) Y_miss= &y_miss (&n_rate3)";
   %end;
  proc print data=&giniout label;
    var DataName obs &yvar &score gini ks opt_gini opt_ks lift_ratio;
  run;
  title3;
%end;

proc datasets library=work nolist;
  delete _temp_indata_gini _gini0 _gini1 _tmp_tab;
run;
quit;

%mend;

%macro gini(indata,score,sortorder,wt,yvar,giniout);
   %gini_core_macro(   indata =&indata,
                      type =LOGIT,
                    score =&score,
                        wt =&wt,
                      yvar =&yvar,
                   giniout =&giniout,
                 sortorder =&sortorder,
                     title =,
                     print =Y
            );
%mend;
