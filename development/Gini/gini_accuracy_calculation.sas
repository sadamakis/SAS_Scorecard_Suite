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
/* Program Name:             ---  gini_accuracy_calculation.sas	           								*/
/* Description:              ---  Part of Gini calculation macros   									*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/

%macro performance_report(
             indatas=,
             seg_var=,
               score=,
                yvar=,
              title1=,
              title2=,
              weight=,
                bins=,
           sortorder=descending,
           tabledata=outdata,
             outfile=RAW.txt,
                type=LOGIT);

%let title1=%sysfunc(translate(&title1,'_',' '));
%let title2=%sysfunc(translate(&title2,'_',' '));
%put indatas=&indatas;
%put seg_var=&seg_var;
%put score=&score;
%put yvar=&yvar;
%put type=&type;
%put sortorder=&sortorder;
%put tabledata=&tabledata;
%put title1=&title1;
%put title2=&title2;
%put server_macro_folder=&server_macro_folder;


%if "&tabledata" eq "" %then %let tabledata=_outdata;
%if %sysfunc(exist(&tabledata)) %then %do;
  proc delete data=&tabledata;run;
%end;

*** identify levels for seg_var;
%let _data1=%scan(&indatas,1,' ');
%let nblevel=0;
%if "&seg_var" ne "" %then %do;
proc sql noprint;
   select count(distinct(&seg_var)) into:nblevel from &_data1;
   select distinct(&seg_var) into:lv1-:%sysfunc(compress(lv&nblevel)) from &_data1;
quit;
%put NB_LEVEL=&nblevel;
%do i=1 %to &nblevel;
    %put level&i: &&lv&i;
%end;
%end;

*** loop through the indatas;
data &tabledata;
run;

%let i=1;
%do %while ("&_data1" ne "" and &i<10);
  %put [&i]:&_data1;
  %do j=0 %to &nblevel;
    %put J=&j;
    %if &j eq 0 %then %do;
       %let _udata=&_data1;
       %let _sdata=&_data1._stat;
       %let _odata=&_data1._out_all;
       %let _llabel=&_data1._[Overall];
       %let page=_Overall_;
     %end;
     %else %do;
       data &_data1._&j;
          set &_data1(where=(&seg_var eq "&&lv&j"));
       run;
       %let _udata=&_data1._&j;
       %let _odata=&_udata._out_all;
       %let _sdata=&_udata._stat;
       %let _llabel=%sysfunc(compress(&_data1._(Seg:&&lv&j)));
       %let page=&&lv&j;
     %end;
     %put &_udata &_odata &page;
     %do k=1 %to 2;
       %if &k=1 %then %do;
           %let eqbads=;%let table=Eq_Vol;
       %end;
       %else %do;
           %let eqbads=Y;%let table=Eq_Bad;
       %end;
     
       %lift_table(indata=&_udata,score=&score,yvar=&yvar,outtab=&_odata,weight=&weight,
                 outstat=&_sdata,sortorder=&sortorder,bins=&bins,type=&type,eqbads=&eqbads);
       data _null_;
         set &_sdata;
         call symput('gini',gini);
       run;
       data &_odata;
         length page $50. data $32. title1 $100. title2 $100. table $8. order 8.;
         set &_odata;
         page="&page";
         data="&_llabel";
         title1="&title1";
         title2="&title2 "; /*%sysfunc(compress((GINI=&gini)))*/
         table="&table";
         order=&j;
       run;
       data &tabledata;
         set &tabledata
           &_odata;
       run;
       proc delete data=&_odata;run;
       proc delete data=&_sdata;run;
     %end;
  %end;
  %let i=%eval(&i+1);
  %let _data1=%scan(&indatas,&i,' '); 
%end;

proc sort data=&tabledata(where=(page ne ''));
  by order;
run;

%if "&outfile" ne "" %then %do;
data _null_;
  file "&outfile";
  set &tabledata;
  put _ALL_;
run;
%end;
%mend;
