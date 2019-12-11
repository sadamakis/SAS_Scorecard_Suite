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
/* Program Name:             ---  quick_format.sas	                           							*/
/* Description:              ---  Part of PSI macros    												*/
/*  VARIABLES   :  * 1st macro parameter   ==> indatas are the datasets to use*/
/*                 * 2nd macro parameter   ==> labels are the datasets labels to use */
/*                 * 3rd macro parameter   ==> model variable list            */
/*                 * 4th macro parameter   ==> Number of max bins for each variable */
/*                 * 5th macro parameter   ==> TEMP datasets that hold ds_psi output */
/*                 * 6th macro parameter   ==> Title for PSI Tables           */
/*                 * 7th macro parameter   ==> weight value or variable       */
/*                 * 8th macro parameter   ==> CANCEL or NO PARAMETER for     */
/*                   print of of Proc Means and Proc Prints                   */
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/

ODS PATH work.templat(update) sasuser.templat(read)
               sashelp.tmplmst(read);

proc template;
                define style Styles.ra_table;
                   parent = styles.default;
                   style fonts /
                      'TitleFont2' = ("Helvetica",14pt,bold)
                      'TitleFont' = ("Helvetica",10pt,bold)
                      'StrongFont' = ("Helvetica",10pt,bold)
                      'EmphasisFont' = ("Helvetica",9pt)
                      'FixedEmphasisFont' = ("Helvetica",9pt)
                      'FixedStrongFont' = ("Helvetica",9pt,bold)
                      'FixedHeadingFont' = ("Helvetica",9pt,bold)
                      'BatchFixedFont' = ("Helvetica",9pt,bold)
                      'FixedFont' = ("Helvetica",9pt,bold)
                      'headingEmphasisFont' = ("Helvetica",10pt,bold)
                      'headingFont' = ("Helvetica",10pt,bold)
                      'docFont' = ("Helvetica",9pt);
                   
                   style colors /
                      'headerfgemph' = cx000000
                      'headerbgemph' = cxFFFFFF
                      'headerfgstrong' = cxFFFFFF
                      'headerbgstrong' = CX201F73
                      'headerfg' = cxFFFFFF
                      'headerbg' = CX201F73
                      'datafgemph' = cx000000
                      'databgemph' = cxFFFFFF
                      'datafgstrong' = cx000000
                      'databgstrong' = cxFFFFFF
                      'datafg' = cx000000
                      'databg' = cxFFFFFF
                      'batchfg' = cx000000
                      'batchbg' = cxFFFFFF
                      'tableborder' = cx000000
                      'tablebg' = cxDFECE1
                      'notefg' = cx000000
                      'notebg' = CXBFBFBF
                      'bylinefg' = cx000000
                      'bylinebg' = cxDFECE1
                      'captionfg' = cx000000
                      'captionbg' = cxDFECE1
                      'proctitlefg' = cx000000
                      'proctitlebg' = CXBFBFBF
                      'titlefg' = cx000000
                      'titlebg' = CXBFBFBF
                      'systitlefg' = cx000000
                      'systitlebg' = CXBFBFBF
                      'Conentryfg' = cx31035E
                      'Confolderfg' = cx31035E
                      'Contitlefg' = cx31035E
                      'link2' = cx800080
                      'link1' = cx0000FF
                      'contentfg' = cx000000
                      'contentbg' = CXBFBFBF
                      'docfg' = cx000000
                      'docbg' = CXBFBFBF;    
                end;
run;

%macro quick_format(indata=,var=,var2=,bins=10,weight=,formatname=myfmt,formatdata=myfmtdata,smallbin=2,debug=No,can=cancel);
*** random temperory filenames;
%let random_n=%sysfunc(ranuni(1234));
%let random_n2=%sysfunc(int(%sysevalf(&random_n*1000)));
%put &random_n2;
%let tmpdata=tmp_fmt_&random_n2;

%if "&formatname" eq "" %then %let formatname=myfmt;
%if "&formatdata" eq "" %then %let formatdata=myfmtdata;

*** get variable type;
data _null_;
set &indata;
if vtype(&var) eq 'C' then call symput('vartype','C');
if vtype(&var) eq 'N' then call symput('vartype','N');
stop;
run;

*********************;
*** Numeric        **;
*********************;
%if "&vartype" eq "N" %then %do;

*** sort the data;
proc sort data=&indata(keep=&var &var2 &weight) out=&tmpdata._0;
by &var;
run;
*** get the total count with weight;
%if "&var2" eq "" %then %do;
proc summary data=&tmpdata._0 noprint;
var &var;
%if "&weight" ne "" %then weight &weight;;
output out=&tmpdata._1 %if "&weight" eq "" %then n=n;
                                           %else SUMWGT=n;;
run;
%let _c_var=1;
%end;
%else %do;
proc summary data=&tmpdata._0(where=(&var2=1)) noprint;
var &var2;
%if "&weight" ne "" %then weight &weight;;
output out=&tmpdata._1 %if "&weight" eq "" %then n=n;
                                           %else SUMWGT=n;;
run;
%let _c_var=&var2;
%end;

data _null_;
set &tmpdata._1 ;
call symput('FMTTOTWN',n);
run;

%let dbin=%sysevalf(&FMTTOTWN/&bins);
data &tmpdata._2;
set &tmpdata._0(keep=&var &var2 &weight where=(&var ne .)) end =last;
retain SumWT 0 SumWTGP 0  end_m  ;
if _n_=1 then do;
   end_m =&var;
end;
%if "&weight" ne "" %then %do;
   SumWT   + &weight*&_c_var;
   SumWTGP + &weight*&_c_var;
%end;%else %do;
   SumWT   + &_c_var; 
   SumWTGP + &_c_var;
%end;
*** find the distinct values, and counts;
if &var>end_m or last then do;
   output;
   SumWTGP =0;
end;
end_m =&var;
run;

data &tmpdata._3;
length start_n end_n dist 8.;
set &tmpdata._2 end=last nobs=nb;
retain CumTOT 0 CumGP 0 last_end 0 GP 1 start_n . last_dist .;
if start_n =. then do; start_n =end_m;last_end =end_m; end;
CumGP + SumWTGP; CumTOT + SumWTGP;
dist =abs(CumGP-&dbin);
if (CumTOT>&dbin*GP and CumGP>0.2*&dbin) or last or nb<=&smallbin then do;
    GP+1;
    if dist>last_dist and last_dist ne . and _n_>1 and nb>&smallbin then do; 
      ** if last dist is smaller, use the last one;
      end_n =last_end; output;
      start_n =end_n;dist =.;CumGP =0;
    end; 
    else do;
      ** if last dist is larger, use the current one;
      end_n =end_m;   output;
      start_n =end_n;dist =.;CumGP =0;
    end;
end;
last_end=end_m;
last_dist=dist;
run;
data &formatdata;
length fmtname $32. label $8. start $50. end $50.;
set &tmpdata._3 end=last;
retain fmtname "&formatname";
label  =compress(put(_n_-1,8.));
start  =compress(put(start_n,best8.));
end    =compress(put(end_n,best8.));
if _n_=1 then start ='LOW';
if last  then   end ='HIGH';
run;

%if %upcase(&debug) ne Y and %upcase(&debug) ne YES %then %do;
proc datasets lib=work nolist;
  delete &tmpdata._0 &tmpdata._1 &tmpdata._2 &tmpdata._3;
run;
quit;
%end;

%end;

*********************;
*** Character      **;
*********************;
%if "&vartype" eq "C" %then %do;

%if %substr(&formatname,1,1) ne '$' %then %let formatname=$&formatname;

ods select none;
proc freq data=&indata(keep=&var ) ;
   table &var;
   ods output OneWayFreqs=&tmpdata._1;
run;
data &formatdata;
  length start $100;
  length end $100;
  set &tmpdata._1 (keep=&var);
  retain fmtname "&formatname";
  start=&var;
  end=&var;
  label=put(_n_-1,4.);
run;
%if %upcase(&debug) ne Y and %upcase(&debug) ne YES %then %do;
proc datasets lib=work nolist;
  delete &tmpdata._1 ;
run;
quit;
%end;

%end;

ods select all;
proc format cntlin=&formatdata fmtlib;
   select &formatname;
run &can;

%mend;



%macro batch_format(indata=,varlist=,fmtlist=,bins=10,weight=);
*** check var list;
%let var1=%scan(&varlist,1,' ');
%let _ki=1;
%do %while ("&var1" ne "" and &_ki<100);
   %let _var&_ki=&var1;
   %let _ki=%eval(&_ki+1);
   %let var1=%scan(&varlist,&_ki,' ');
%end;
%let _nbvar=%eval(&_ki-1);
*** check format list;
%let fmt1=%scan(&fmtlist,1,' ');
%let _ki=1;
%do %while ("&fmt1" ne "" and &_ki<100);
   %let _fmt&_ki=&fmt1;
   %let _ki=%eval(&_ki+1);
   %let fmt1=%scan(&fmtlist,&_ki,' ');
%end;
%let _nbfmt=%eval(&_ki-1);

%if &_nbvar ne &_nbfmt %then %do;
   %put "***********************************************";
   %put "Different number between variables and formats ";
   %put "***********************************************";
   %goto ENDIT;
%end;

%do _kki=1 %to &_nbvar;
  %quick_format(indata=&indata,
               var=&&_var&_kki,
              bins=&bins,
             weight=&weight,
         formatname=&&_fmt&_kki);
%end;

%ENDIT:
%mend;