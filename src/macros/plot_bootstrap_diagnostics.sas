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
/* Program Name:             ---  plot_bootstrap_diagnostics.sas										*/ 
/* Description:              ---  This macro plots the intercept, log likelihood and the predictor's 
coefficients to check for convergence																	*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro plot_bootstrap_diagnostics(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
);


proc contents data=&predictors_coefficients_outtable.  (drop= _LINK_ _NAME_ _STATUS_ _TYPE_) out=&predictors_coefficients_outtable._c (keep= NAME) noprint;
run;
proc sql noprint;
select name into :bootstrap_variables separated by ' '
from &predictors_coefficients_outtable._c
;
quit;
%put &bootstrap_variables.;
%put %sysfunc(countw(&bootstrap_variables.));

data predictors_coefficients_summary;
retain iteration;
	set &predictors_coefficients_outtable.;
	iteration = _n_;
%do i=1 %to %sysfunc(countw(&bootstrap_variables.));
%let var=%scan(&bootstrap_variables., &i.);
%put ****** Variable &var. ******;
	retain &var._mean;
	if _n_=1 then do;
		&var._sum=0;
		&var._mean=0;
	end;
	&var._sum + &var.;
	&var._mean = &var._sum/iteration;
	keep &var. &var._mean;
%end;
	keep iteration;
run;

goptions reset=all;
symbol1 color=blue value=dot interpol=join;
proc gplot data=predictors_coefficients_summary;
%do i=1 %to %sysfunc(countw(&bootstrap_variables.));
%let var=%scan(&bootstrap_variables., &i.);
	 plot &var._mean*iteration;
%end;
run;
goptions reset=all;

proc sql noprint;
	drop table &predictors_coefficients_outtable._c;
quit;

%mend plot_bootstrap_diagnostics;
