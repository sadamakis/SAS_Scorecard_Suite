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
/* Program Name:             ---  psi_execution.sas	                           							*/
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

options ls = 150 nocenter nodate nonumber errors=1;

%macro psi_execution(indatas  =,
                     labels  =,
                    varlist  =,
                    fmtlist  =,
                       bins  =10,
                    outtabs  =outtabs,
                    outstats =outstats,
                    title    =,
                    weight   =,
                    can      =cancel);

** get list of variables;
%let _psivar=%scan(&varlist,1,' ');
%let _ki=1;
%do %while ("&_psivar" ne "" and &_ki<100);
   %let _psivar&_ki=&_psivar;
   %let _ki=%eval(&_ki+1);
   %let _psivar=%scan(&varlist,&_ki,' ');
%end;
%let _nbvar=%eval(&_ki-1);

%if &fmtlist ne %then %do;

%let _fmt=%scan(&fmtlist ,1,' ');
%let _ki=1;
%do %while ("&_fmt" ne "" and &_ki<100);
   %let _fmt&_ki=&_fmt;
   %let _ki=%eval(&_ki+1);
   %let _fmt=%scan(&fmtlist,&_ki,' ');
%end;

%end;

* Acquire LABEL to merge with final dataset;

%let psildata=%scan(&indatas,1,' ');

* Send proc contents to a dataset;

proc contents data=&psildata noprint out=psilabel;
run;

* rename variable to those in the output dataset;

data psilabel;
     set psilabel(rename=(name=var label=vlabel));
run;

data &outtabs;run;
data &outstats;run;

%do _kki=1 %to &_nbvar;
%psi_macro(indatas  =&indatas,
         score   =&&_psivar&_kki,
         title   =&title,
         labels  =&labels,
         weight  =&weight,
         %if &fmtlist ne %then scoreinfmt =&&_fmt&_kki,;
         bins    =&bins,
         outtab  =outtab,
         outstat =outstat,
             can =&can);

data &outtabs;
     set &outtabs outtab;
run;
data &outstats;
  set &outstats
      outstat;
run;

%end;

* Add Labels to use in Tabulate via HASH table;

data work.outstats;
     length var $ 32 vlabel $ 80 xvlabel $ 135;

     if _n_ = 1 then do;
        declare hash ht(dataset:"psilabel");
        ht.definekey("var");
        ht.definedata("vlabel");
        ht.definedone();
     end;

     set work.outstats;

     rc = ht.find();

     if vlabel = " " then xvlabel = var;
     else xvlabel = trim(var) !! " : " !! trim(vlabel);

run;

     
proc print data=&outstats;
run /*&can */;

proc format;
     Value psic low-<0.1 ='strong yellow-green'
                0.1-<2.5 ='Orange'
                other    ='Red';
run;

ods listing close;
ods html file="&output_directory./&program..html" ; 
ods tagsets.ExcelXP file="&output_directory./&program..xml" /*style=minimal*/ ;

proc format;
     Value psic low-<0.1 ='strong yellow-green'
                0.1-<.25 ='Orange'
                .25-high ='Red';
run;

title "PSI for All Datasets and All Variables";

data exdev/view=exdev;
     set work.outstats;
     if data NE " ";
     if label NE "DEVELOPMENT";
run;

proc tabulate data=exdev order=data;
     class label xvlabel;
     var psi;
     Table xvlabel="Variable", label="Dataset" * psi=""*sum=""*f=10.4*{style={background=psic.}} / MISSTEXT = " ";
run;

ods tagsets.ExcelXP close;
ods html close;
ods listing;


%mend;