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
/* Program Name:             ---  psi_macro.sas	                           								*/
/* Description:              ---  Part of PSI macros    												*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/

%macro psi_macro(
         indatas =,          /* input datasets, like data1 data2 data3 */
          labels =,          /* a series of labels to show data names */
       outtab =outtab,    /* output data contains PSI table */
         outstat =outstat,   /* output data contains PSI values */
           title =,          /* title for the project */
           score =,          /* the variable to calculate PSI */
      scoreinfmt =,          /* For numeric variable, a format can be used */
   outfmtdata =outfmtdata,/* For numeric variable, a format can be outputed */
          weight =,          /* weight variable */
            bins =10,        /* number of decile */
         noprint =NO,
             can =cancel,
           debug =No
            );

%let _ct=%sysfunc(time());;

proc format;
     Value psic low-<0.1 ='strong yellow-green'
                0.1-<.25 ='Orange'
                .25-high ='Red';
run;

***random temperory filenames;
%let random_n=%sysfunc(ranuni(1234));
%let random_n2=%sysfunc(int(%sysevalf(&random_n*1000)));
%put &random_n2;
%let sum=sum_&random_n2;

title2 "&title";;

%if not %symexist(eps)   %then %let eps=0.000001;
%if "&outtab"      eq "" %then %let outtab=outtab;
%if "&outstat"     eq "" %then %let outstat=outstat;
%if "&outfmtdata"  eq "" %then %let outfmtdata=outfmtdata;
%if &weight        eq 1  %then %let weight=;

**Get Data Names;
%let _psidata=%scan(&indatas,1,' ');
%let _ki=1;
%do %while ("&_psidata" ne "");
   %let _psidata&_ki=&_psidata;
   %let _ki=%eval(&_ki+1);
   %let _psidata=%scan(&indatas,&_ki,' ');
%end;
%let _nbdata=%eval(&_ki-1);

** Get Labels;
%let _psilabel=%scan(&labels,1,' ');
%let _ki=1;
%do %while ("&_psilabel" ne "");
   %let _psilabel&_ki=&_psilabel;
   %let _ki=%eval(&_ki+1);
   %let _psilabel=%scan(&labels,&_ki,' ');
%end;
%let _nblabel=%eval(&_ki-1);

** if label < data then set label as id;
%do _ki=&_nblabel+1 %to &_nbdata;
  %let _psilabel&_ki=&_ki;
%end;

** determine numeric variable or character variable;
data _null_;
set &_psidata1;
if vtype(&score) eq "N" then call symput('vartype',compress('N'));
if vtype(&score) eq "C" then call symput('vartype',compress('C'));
stop;
run;

** if summary_1 exist, delete it to avoid possible problems;
%if %sysfunc(exist(&sum._1))     %then proc delete data=&sum._1;;
%if %sysfunc(exist(&outtab))     %then proc delete data=&outtab;;
%if %sysfunc(exist(&outstat))    %then proc delete data=&outstat;;
%if %sysfunc(exist(&outfmtdata)) %then proc delete data=&outfmtdata;;
run;

** if no scoreinfmt, create it based on the first data;
%if "&scoreinfmt" eq "" %then %do;
  %if "&vartype" eq "N" %then %do;
    %quick_format(indata=&_psidata1,var=&score,bins=&bins,weight=&weight,formatname=scoreinfmt,formatdata=&outfmtdata,smallbin=2,can=&can);
    %let scoreinfmt=scoreinfmt;
  %end;
  %if "&vartype" eq "C" %then %do;
    %quick_format(indata=&_psidata1,var=&score,formatname=scoreinfmt,formatdata=&outfmtdata,can=&can);
    %let scoreinfmt=$scoreinfmt;
  %end;
%end;

** if scoreinfmt is set, use it to divide all data, use the 1st data as benchmark;
%if "&scoreinfmt" ne "" %then %do;
   %do _ki=1 %to &_nbdata;
     title3 "&&_psidata&_ki";
     %if "&vartype" eq "N" %then %do; /* For numeric variables */
     ods select none;
     proc summary data=&&_psidata&_ki(keep=&score &weight) missing noprint;
       class &score;
       format &score &scoreinfmt..;
       var &score;
       %if "&weight" ne "" %then weight &weight;;
       output out=&sum._&_ki mean=mean  max=max
               sumwgt=wN 
       ;
    run;
    %l1:
    %let totN&_ki=0;%let mean&_ki=;
    data _null_;
      set  &sum._&_ki (where=(_TYPE_=0));
       %if "&weight" ne ""  %then call symput("totN&_ki",put(wN,best12.));
                            %else call symput("totN&_ki",put(_FREQ_,12.));;
      call symput("mean&_ki",put(mean,best12.));
    run;
    data  &sum._&_ki;
       length _rowid $50;
       set &sum._&_ki(where=(_TYPE_=1)) end=last nobs=nb;
       retain cumpct 0;
       _rowid=compress(put(max,&scoreinfmt..));
       %if "&weight" ne ""  %then N=WN; %else N=_FREQ_;;
       do ikk=1 to 4-length(_rowid); _rowid='0'||_rowid;end;
       percent&_ki=N/&&totN&_ki;  psi&_ki=.;
       cumpct+percent&_ki;        nb&_ki=N; 
       label nb&_ki    ="N(&&_psilabel&_ki)" percent&_ki ="Pct(&&_psilabel&_ki)" psi&_ki ="PSI(&&_psilabel&_ki)"; ;
       format percent&_ki percent8.2;
       output;
       if last then do;
          _rowid="~~~[TOTAL]~~~";
          nb&_ki=&&totN&_ki;   percent&_ki=cumpct;
          call symput("nblevel&_ki",put(nb,8.));
          drop cumpct ikk;
          output;
      end;
     run;
   %end;
   %if "&vartype" eq "C" %then %do;
      %if "%substr(&scoreinfmt,1,1)" ne "$" %then %let scoreinfmt=$&scoreinfmt;
         ods select none;
         proc freq data=&&_psidata&_ki(keep=&score &weight) ;
           table &score/missing;
           %if "&weight" ne ""  %then weight &weight;;
           format &score &scoreinfmt..;;
           ods output OneWayFreqs=&sum._&_ki;
         run;
         data &sum._&_ki;
           length _rowid $50. ;
           set &sum._&_ki(keep=&score Frequency percent) end=last nobs=nb;
           retain cumpct cumN 0;
           _rowid=compress(put(&score,&scoreinfmt..));
           do ikk=1 to 4-length(_rowid); _rowid='0'||_rowid;end;
           nb&_ki=Frequency;percent&_ki=percent/100;psi&_ki=.;;
           cumpct+percent&_ki;cumN+Frequency;
           label nb&_ki    ="N(&&_psilabel&_ki)" percent&_ki ="Pct(&&_psilabel&_ki)" psi&_ki ="PSI(&&_psilabel&_ki)";
           format percent&_ki percent8.2;
           output;
           if last then do;
              _rowid="~~~[TOTAL]~~~";
              nb&_ki=cumN;   percent&_ki=cumpct;
              call symput("nblevel&_ki",put(nb,8.));
              call symput("totN&_ki",put(cumN,12.));
              drop cumpct cumN &score Frequency percent ikk;
              output;
           end;
        run;
   %end;
   proc sort data=&sum._&_ki;
     by _rowid;
   run;
   %end;
   ** summarize;
   proc format cntlout=&outfmtdata;
     select &scoreinfmt;
   run;
   data &sum._tmp_format;
     length _rowid $50.;
    set &outfmtdata(keep=start end label);
     _rowid=compress(label);
     do ikk=1 to 4-length(_rowid); _rowid='0'||_rowid;end;
     start=compress(start);
     end=compress(end);
     drop ikk;
   run;
   proc sort data=&sum._tmp_format;
     by _rowid;
   run;
   data &outtab;
     merge &sum._tmp_format
       %do _ki=1 %to &_nbdata;
           &sum._&_ki(keep=_rowid nb&_ki percent&_ki 
            %if &_ki>1 %then psi&_ki;)
       %end;
    ;
    by _rowid;
   run;
   %if &_nbdata>1 %then %do;
    data &outtab;
     length var $32. score_rank $50. ;
     set &outtab end=last;
     var="&score";
     score_rank=_rowid;
     %do _ki=2 %to &_nbdata;
        if nb&_ki=.      then nb&_ki=0;
        if percent&_ki=. then percent&_ki=0;
        psi&_ki=(percent1-percent&_ki)*log((percent1+&eps)/(percent&_ki+&eps));
        if psi&_ki=. then psi&_ki=0;
        cumpsi&_ki+psi&_ki;
        format psi&_ki 8.4;
     %end;
     if last then do;
        score_rank='Total';
        %do _ki=2 %to &_nbdata;
           psi&_ki=cumpsi&_ki;
           drop cumpsi&_ki;
        %end;
     end;
     label score_rank='Rank';
   run;
%end;
%end;

%if "&outstat" ne "" %then %do;
proc sql noprint;
   %do _ki=2 %to &_nbdata; 
     %let psi&_ki=.;
     select psi&_ki into:psi&_ki from &outtab where 
         _rowid="~~~[TOTAL]~~~";;
   %end;
quit;
data &outstat;

   length data $32. var $32. Type $1. label $50. ;;
   %do _ki=1 %to &_nbdata;
     data="&&_psidata&_ki";
     var="&score";
     Type="&vartype";
     %if "&vartype" eq "N" %then score_mean=&&mean&_ki;;
     label="&&_psilabel&_ki";;
     n=&&totN&_ki;
     NLevel=&&nblevel&_ki;
     %if &_ki=1 %then Benchmark="Y";
     %else %do;
        Benchmark="N";
        psi=&&psi&_ki;
      %end;
      ;
    output;
   %end;
  run;
%end; 

*** print out PSI table;
ods select all;
%if %upcase(&noprint) ne YES %then %do; 
 %let _weightind=;
%if "&weight" ne "" %then %let _weightind= (weight:&weight);
title3 "Characteristic Analysis for: &score &_weightind";
proc report data=&outtab nowindows headline headskip missing ;
  column score_rank 
   %if %upcase(&vartype) eq N %then  start end ;
   %else start;
   %do _ki=1 %to &_nbdata;
        ("&&_psilabel&_ki" (nb&_ki percent&_ki %if &_ki>1 %then psi&_ki;))
   %end;
   ;
  define score_rank    /  display  width = 12      "&score rank"     ;
  %if %upcase(&vartype) eq N %then %do;
    define start       /  display  width = 12      "Minimum &score" ;
    define end         /  display  width = 12      "Maximum &score" ;
  %end;
  %else define start   /  display  width = 12      "Value"         ;;
  define nb1           /  display  width = 10  format=6.0    "N"            ;
  define percent1      /  display  width = 10      "%"            ;
  %do _ki=2 %to &_nbdata; 
     define nb&_ki     /  display  width = 10   format=6.0   "N"           ;
     define percent&_ki/  display  width = 10      "%"            ;
     define psi&_ki    /  display  width = 10 style={background=psic.}   "psi"         ;
  %end;
run;
%end;

** clean the datasets;
%if %upcase(&debug) ne Y and %upcase(&debug) ne YES %then %do;
proc datasets nolist;
  delete &sum._tmp_format
   %do _ki=1 %to &_nbdata;
  &sum._&_ki
   %end;
   ;
run;
quit; 
%end;


title2;
%let _ct2=%sysfunc(time());
%let _ct3=%sysfunc(int(&_ct2-&_ct));
%put NOTE-******* TOTAL ELAPSE TIME: &_ct3 s **********;

%mend;
   
