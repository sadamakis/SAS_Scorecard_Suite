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
/* Program Name:             ---  lift_table_macro.sas	           								*/
/* Description:              ---  Part of Gini calculation macros   									*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/


%MACRO lift_table (indata =,                      /* indata: the input dataset*/
                   datalabel =,         /* labels for the dataset */
                       score =,               /* score: the variable in the indata which stores the p score (1/(1+exp(-Ey)))*/
                  scoreinfmt =,         /* scorefmt: a format name, divide scores into bins by scorefmt. If set, bins and binmethod will be ignored */
                   sortorder =,         /* descend: can be none or descending, if the proc logistic is using descending, it should 
                                            also use descending */
                        yvar =,                /* yvar: the Y variable, must be 0 and 1 */
                                         title =, 
                      weight =,         /* the weight*/
                        bins =20,       /* bins: the number of groups to divide data*/
                        type =LOGIT,    /* Linear|Logit, for linear: LIN or LINEAR, for logit: LOG or LOGIT */
                   outformat =,         /* output a format which contains score band */
                      outtab =outtab,   /* a dataset contains the lift table*/
                     outstat =outstat,  /* a dataset contains the statistics (ks, gini, bad_mean, n) */
                      eqbads =NO,
                              noprint =NO        /* YES or NO, whether to suppress the output print*/ 
                 );
***random temperory filenames;
%let random_n=%sysfunc(ranuni(1234));
%let random_n2=%sysfunc(int(%sysevalf(&random_n*1000)));
%put &random_n2;
%let liftdata=tmp_lift_&random_n2;


%if %upcase(&sortorder) eq DESCEND %then %let sortorder=descending; 
%if %upcase(&sortorder) eq ASCEND  or %upcase(&sortorder) eq ASCENDING 
                                   %then %let sortorder=; 

%if &weight eq 1                   %then %let weight=;
%if "&outformat" eq ""             %then %let outformat=outformat;
%if "&datalabel" eq ""             %then %let datalabel=&indata;

/*select all records with yvar ans score is not missing*/
proc sort data=&indata (keep=&score &yvar &weight where=(&yvar ne . and &score ne .))
          out=&liftdata._0;
  by &score;
run;
/* basic statistics */
proc summary data=&liftdata._0 noprint;
  var &yvar &score;
  %if "&weight" ne "" %then weight &weight;;
  output out=&liftdata._1 mean =ymean scoremean
                           min =ymin  scoremin
                           max =ymax  scoremax
                           N=N
                           %if "&weight" ne "" %then  sumwgt= WN;
  ;
run;
data _null_;
  set &liftdata._1;
  call symput ('_ymean',    put(ymean,best12.));
  call symput ('_scoremean',put(scoremean,best12.));
  call symput ('_ymin',     put(ymin,best12.));
  call symput ('_scoremin', put(scoremin,best12.));
  call symput ('_ymax',     put(ymax,best12.));
  call symput ('_scoremax', put(scoremax,best12.));
  call symput ('_nsize',    put(n,best12.));
  %if "&weight" ne "" %then call symput ('_nwsize',    put(WN,best12.));
                      %else call symput ('_nwsize',    put(N,best12.));
   ;
run;
%if &_nsize le 0 %then %do;
  %put "0 scored observation in the data, calculation cannot continue";
  %goto ENDIT;
%end;

%let _nbad=%sysevalf(&_ymean*&_nwsize);
%let _nbad=%sysfunc(round(&_nbad));
%let _ngood=&_nsize-&_nbad;
  
** get gini values;
%gini_core_macro(indata=&liftdata._0,label=&datalabel,score=&score,sortorder=&sortorder,
             yvar=&yvar, type=&type,wt=&weight, giniout=giniout);
data _null_;
  set giniout;
  call symput('gini_cv',put(gini*100,6.1-l));
  call symput('ks_cv',put(ks*100,6.1-l));
  if &_nbad+&_ngood>0 then cv95=put((((log(1/0.025))/(2*((&_nbad*&_ngood)/(&_nbad+&_ngood))))**(1/2))*100,6.2);
                      else cv95=.;
  call symput('cv95',cv95);
  call symput ('R2',put(R2,6.3));
  call symput ('lift_ratio',put(lift_ratio*100,6.1));
run;


**if not format, get it throught NumFMT;
%if "&scoreinfmt" eq "" %then %do;
  %if %upcase(&eqbads) ne Y and %upcase(&eqbads) ne YES %then %let var2=;
                                                        %else %let var2=&yvar;
      %quick_format(indata=&liftdata._0,
              var=&score,
              bins=&bins,
              var2=&var2,
             weight=&weight,
             formatname=&outformat);
      %let scoreinfmt=&outformat;
%end;

** apply the format to the data to get freq table;
proc summary data=&liftdata._0 noprint;
   var &score &yvar;
   by  &score;
   format &score &scoreinfmt..;
   %if "&weight" ne "" %then weight &weight;;
   output out  =&liftdata._2
          min  =score_Min   y_Min 
          max  =score_Max   y_Max
          mean =score_Mean  y_Mean 
          sum  =score_Sum   y_Sum 
          N=Ncounts
          %if "&weight" ne "" %then SumWGT=WtNcounts;
     ;
run;


  proc sort data=&liftdata._2;
    by &sortorder  score_Min;
  run;


/*got the table in the dataset */
  data &outtab;
    length data $32. label $32.;
    length Rank     Ncounts  npercent  WtNcounts  WnPercent Score_Min Score_Max Score_Mean 
           exp_bad  bad_rate act_bad   tpercent   bpercent  gpercent  lift      ctot
           cbad     cgood 8.;
    set &liftdata._2 end=last;
    retain ctot cbad cgood 0 ks_bin;
    %if "&weight" eq "" %then WtNcounts=Ncounts;;
    data="&indata";label="&datalabel";
    if &_nsize>0 and &_nwsize>0 then do;
      npercent  =Ncounts/&_nsize; 
      Wnpercent =WtNcounts/&_nwsize;
      cbad   +  y_mean*WtNcounts;
      cgood  +  (1-y_mean)*WtNcounts;
      ctot   +  WtNcounts;
      exp_bad   =score_mean*WtNcounts;
      bad_rate  =y_mean;  
      act_bad   =y_mean*WtNcounts;
      tpercent  =ctot/&_nwsize;
      if &_ymean ne 0 and &_ymean ne .  then bpercent  =cbad/&_ymean/&_nwsize;else bpercent  =.;
      if &_ymean ne 1 and &_ymean ne .  then gpercent  =cgood/(1-&_ymean)/&_nwsize;else gpercent  =.;
      if tpercent >0 then lift      =(bpercent-tpercent)/tpercent; else lift=.;
      predict   =score_mean;
      actual    =bad_rate;
      diffp     =abs(bpercent-gpercent);
      ks_bin    =max(ks_bin,diffp);
      plot      ="plot";
    end;
    output;
    if last then do;
       rank        =.;          ncounts     =&_nsize;    npercent    =1;
       WtNcounts   =&_nwsize;   Wnpercent   =1;          score_min   =&_scoremin;
       score_max   =&_scoremax; score_mean  =&_scoremean;exp_bad     =&_scoremean*&_nwsize;
       act_bad     =&_nbad;     bad_rate    =&_ymean;    
       tpercent    =.;          bpercent    =.;          gpercent    =.;
       cbad        =.;          cgood       =.;          ctot        =.;
       lift        =.;          plot        ="";         predict     =&_scoremean;
       actual      =&_ymean;
       call symput('ks_bin',put(ks_bin*100,6.2));
       output;
    end;
    format score_min score_max score_mean 10.4;
    format WtNcounts exp_bad act_bad 8.0;
    format bad_rate Wnpercent tpercent bpercent gpercent lift percent8.1; 
  run;
    
*** print the results;
%if %sysfunc(upcase(&noprint)) eq NO %then %do;
  title2 " &title ";
  title3 " DATA = &datalabel   Y = &yvar    score = &score";
  
  %if %upcase(&type) eq LOGIT or %upcase(&type) eq LOG %then %do;
     title4 " Gini(cv) = %sysfunc(compress(&gini_cv)) KS = %sysfunc(compress(&ks_cv)) KS_bin = %sysfunc(compress(&ks_bin)) "; 
     proc report data= &outtab nowindows headline headskip /*out=&outtab*/;
        column  ncounts npercent
        %if "&weight" ne "" %then wnpercent; 
        score_Min score_Max score_Mean exp_bad
                       bad_rate act_bad tpercent bpercent gpercent lift;
       
        define npercent     /display f=percent6.1 width=6 '% of all accounts' center;
        %if "&weight" ne "" %then 
            define wnpercent/display f=percent6.1 width=6 'wt.% of all counts' center;;
        define ncounts      /display f=7. width=6 '# of accounts' center;
        define score_Min    /display f=8.4 width=9 'Min score' center;
        define score_Max    /display f=8.4 width=9 'Max score' center;
        define score_Mean   /display f=percent8.2 width=9 'Avg score' center;
        define exp_bad      /display f=7. width=8 'exp. # of bads' center;
        define bad_rate     /display f=percent8.2 width=9 'actual bad rate' center;
        define act_bad      /display f=5. width=6 'actual # of bads' center;
        define tpercent     /display f=percent7.1 width=8 'Cumm. % of all' center;
        define bpercent     /display f=percent7.1 width=7 'Cumm. % of bads' center;
        define gpercent     /display f=percent7.1 width=7 'Cumm. % of goods' center;
        define lift         /display f=percent7.1 width=7 'lift' center ;
    run;
  %end;
  %else %do;
    title4 " Gini(cv) = %sysfunc(compress(&gini_cv)) GINI_Ratio = %sysfunc(compress(&lift_ratio)) R2 = %sysfunc(compress(&R2)) "; 
    proc report data= &outtab nowindows headline headskip /*out=&outtab*/;
        column  ncounts npercent
        %if "&weight" ne "" %then wnpercent; 
        score_Min score_Max score_Mean 
                       bad_rate  tpercent bpercent lift;
       
        define npercent     /display f=percent6.1 width=6 '% of all accounts' center;
        %if "&weight" ne "" %then 
            define wnpercent/display f=percent6.1 width=6 'wt.% of all counts' center;;
        define ncounts      /display f=7. width=6 '# of accounts' center;
        define score_Min    /display f=8.4 width=9 'Min score' center;
        define score_Max    /display f=8.4 width=9 'Max score' center;
        define score_Mean   /display f=10.4 width=14 'Avg score' center;
        define bad_rate     /display f=10.4 width=14 'Avg Y' center;
        define tpercent     /display f=percent7.2 width=8 'Cumm. % of all' center;
        define bpercent     /display f=percent7.2 width=7 'Cumm. % of Y' center;
        define lift         /display f=percent7.2 width=7 'lift' center ;
    run;

  %end;
%end;

%if "&outstat" ne "" %then %do;
  /** if it is a linear model, use lift_ratio to replace gini_cv; **/
   %if %upcase(&type) eq LINEAR or %upcase(&type) eq LIN %then %do;
     %let gini_cv=&lift_ratio;
   %end;
   data  &outstat;
     length data $32.;
     n        =&_nsize;   WtN     =&_nwsize; type     ="&type"; 
     gini     =&gini_cv;  ks       =&ks_cv;  ks_bin   =&ks_bin;    
     cv95     =&cv95;     
     badmean  =&_ymean;   scoremean=&_scoremean; nbad =&_nbad;
     R2       =&R2;
     data     ="&datalabel";
     lift_ratio=&lift_ratio;
    run;
%end;

  proc datasets library=work nolist;
     delete &liftdata._0 &liftdata._1 &liftdata._2;
  run;
  quit;
  title2;


%ENDIT:
%MEND ;

