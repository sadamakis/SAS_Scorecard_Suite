/* Disclaimer
Coyright (C), Sotirios Adamakis
This software may be used, copied, or redistributed only with the permission of Sotirios Adamakis. 
If used, copied, or redistributed it should not be sold and this copyright notice should be reproduced 
on each copy made. All code in this document is provided "as is" by Sotirios Adamakis without warranty 
of any kind, either express or implied, including but not limited to the implied warranties of 
merchantability and fitness for a particular purpose. Recipients acknowledge and agree that 
Sotirios Adamakis shall not be liable for any damages whatsoever arising out of their use of this 
material. In addition, Sotirios Adamakis will provide no support for the materials contained herein.
*/
/*------------------------------------------------------------------------------------------------------*/
/* Author:                   ---  Sotirios Adamakis                                                     */
/* Program Name:             ---  logistic_regression.sas												*/ 
/* Description:              ---  Macro that takes as input development and validation samples and 
builds a logistic regression model on the development sample											*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro logistic_regression(
/***********************************************************************************/
/*Input*/
modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable,  /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
model_selection_method, /*Choose from none, stepwise, backward, forward, score*/
slentry, /*Entry criteria for model selection method*/
slstay, /*Stay criteria for model selection method*/
force_numeric_vars, /*List of numeric variables, separated by space, that should be forced in the model. 
These are going to be the only numeric variables in the model. If no variables will be forced in the model, 
then leave this blank.*/
force_character_vars, /*List of character variables, separated by space, that should be forced in the model. 
These are going to be the only character variables in the model. If no variables will be forced in the 
model, then leave this blank.*/
force_interactions, /*List of interactions, separated by space, that should be forced in the model. 
If no interactions will be forced in the model, then leave this blank.*/
use_interactions, /*Y if 2-way interactions of ALL the variables will be used in the model*/
/***********************************************************************************/
/*Output*/
output_model, /*Dataset with the logistic regression model*/
output_coefficients, /*Dataset with the coefficients from the final model*/
outtable_development_score, /*Development sample with the predicted probability*/
outtable_validation_score, /*Validation sample with the predicted probability*/
outtable_model_build_summary /*Model building summary table*/
);

%let numeric_variables_to_analyse=;
%let character_variables_to_analyse=;

proc contents data=&modelling_data_development. (drop=&target_variable. &id_variable. &weight_variable.) noprint out=contents;
run;
proc sql noprint;
select name into :numeric_variables_to_analyse separated by ' '
from contents
where TYPE=1
;
quit;
proc sql noprint;
select name into :character_variables_to_analyse separated by ' '
from contents
where TYPE=2
;
quit;

%if (%length(&force_numeric_vars.) = 0) %then %do;
%let varlist_cont=&numeric_variables_to_analyse.;
%end;
%else %do;
%let varlist_cont=&force_numeric_vars.;
%end;
%if (%length(&force_character_vars.) = 0) %then %do;
%let varlist_disc=&character_variables_to_analyse.;
%end;
%else %do;
%let varlist_disc=&force_character_vars.;
%end;

%if &use_interactions. = Y %then %do;
%let varlist_cont = %sysfunc(TRANWRD(&varlist_cont. &varlist_disc., %STR( ), |)) @2;
%end;
%else %do;
%let varlist_cont = &varlist_cont.;
%end;

%put The numeric variables that will go into the logistic regression are: &varlist_cont.;
%put The character variables that will go into the logistic regression are: &varlist_disc.;

ods output ModelBuildingSummary=outtable_model_build_summary
			FitStatistics=FIT;
proc logistic data=&modelling_data_development. outmodel=&output_model. outest=&output_coefficients. namelen=200;
      class &varlist_disc. / param=ref ;
      model &target_variable. (event='1') = &varlist_cont. &varlist_disc. &force_interactions. / link=logit
            expb
            selection=&model_selection_method.
            slentry=&slentry.
            slstay=&slstay.
            details
            lackfit
			maxiter=50
			ctable 
			pprob=0.5;
	  weight &weight_variable.;
    output out=&outtable_development_score. p=ppred xbeta=logit predprob=(individual crossvalidate);
	score data=&modelling_data_validation. out=&outtable_validation_score.;
run;
ods output close;

data &outtable_model_build_summary.;
	set outtable_model_build_summary;
run;

%mend logistic_regression;
/**********************************************************************************************/
