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
/* Program Name:             ---  gini_for_set_predictors.sas											*/
/* Description:              ---  Calculate Gini for set number of predictors. Requirement for this 
code is to have a model build summary dataset, which can be obtained after running a model 
selection (e.g. stepwise) PROC LOGISTIC. The code selects the top X predictors that go into the model.	*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro gini_for_set_predictors(
/***********************************************************************************/
/*Input*/
input_model_build_summary, /*Model building summary dataset. This dataset is created when enabling 
ModelBuildingSummary option in PROC LOGISTIC*/
input_number_variables_in_model, /*Number of variables that will be in the model.*/
modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable,  /*Name of target variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/***********************************************************************************/
/*Output*/
output_model, /*Dataset with the logistic regression model*/
output_coefficients, /*Dataset with the coefficients from the final model*/
outtable_development_score, /*Development sample with the predicted probability*/
outtable_validation_score, /*Validation sample with the predicted probability*/
outtable_gini_development, /*Table that calculates the Gini coefficient for the development sample*/
outtable_gini_validation /*Table that calculates the Gini coefficient for the validation sample*/
);

proc sql noprint;
select min(Step) into :minimum_step 
from &input_model_build_summary.
where NumberInModel=&input_number_variables_in_model.
;
quit;
%put The minimum step for the selected variables in the model is &minimum_step.;

data model_build_summary;
	set &input_model_build_summary.;
	where step<=&minimum_step.;
run;

%let EffectRemoved=;
%let Step=;
proc sql noprint;
select EffectRemoved, Step into :EffectRemoved separated by ' ', :step separated by ' '
from model_build_summary
where EffectRemoved is not null
;
quit;
%put The removed predictors are: &EffectRemoved.;
%put The step that the predictors were removed is: &step.;

%if (%length(&EffectRemoved.) = 0) %then %do;
data ModelBuildingSummary_final;
      set model_build_summary;
run;
%end;
%else %do;
data ModelBuildingSummary_final;
      set model_build_summary;
		%do i=1 %to %sysfunc(countw(&step.));
			if EffectEntered="%scan(&EffectRemoved., &i.)" and step<%scan(&step., &i.) then delete;
		%end;
      where missing(EffectRemoved);
run;
%end;

data ModelBuildingSummary_final;
	set ModelBuildingSummary_final;
    variable_order = _n_;
run;

/*Select the first n variables and calculate the Ginis*/
proc contents data=&modelling_data_development. out=development_contents noprint;
run;
proc sql;
create table ModelBuildingSummary_predictors as
select 
	t1.*
	, case when t2.TYPE=2 then 'CHARACTER'
		when t2.TYPE=1 then 'NUMERIC' 
		else 'INTERACTION'
	end as variable_type format $20.
from ModelBuildingSummary_final as t1
left join development_contents as t2
on t1.EffectEntered = t2.NAME
where t1.variable_order<=&input_number_variables_in_model.
order by variable_order
;
quit;

data ModelBuildingSummary_numeric ModelBuildingSummary_character;
	set ModelBuildingSummary_predictors;
	if variable_type in ('NUMERIC', 'INTERACTION') then output ModelBuildingSummary_numeric;
	else if variable_type='CHARACTER' then output ModelBuildingSummary_character;
run;

%let numeric_variables_to_analyse=;
%let character_variables_to_analyse=;
proc sql noprint;
select EffectEntered into: numeric_variables_to_analyse separated by ' '
from ModelBuildingSummary_numeric
;
quit;
proc sql noprint;
select EffectEntered into: character_variables_to_analyse separated by ' '
from ModelBuildingSummary_character
;
quit;
%let varlist_cont = &numeric_variables_to_analyse.;
%let varlist_disc = &character_variables_to_analyse.;
%put The numeric variables in the model are: &numeric_variables_to_analyse.;
%put The character variables in the model are: &character_variables_to_analyse.;

proc logistic data=&modelling_data_development. outmodel=&output_model. outest=&output_coefficients.;
      class &varlist_disc. / param=ref ;
      model &target_variable. (event='1') = &varlist_cont. &varlist_disc. / link=logit
            expb
            selection=none
            details
            lackfit
                  maxiter=50
                  ctable 
                  pprob=0.5;
			weight &weight_variable.;
    output out=&outtable_development_score. p=ppred xbeta=logit predprob=(individual crossvalidate);
      score data=&modelling_data_validation. out=&outtable_validation_score. ;
run;

%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = &outtable_development_score., /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable., /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = IP_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = &outtable_gini_development. /*Dataset that contains the Gini coefficient*/
);
%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = &outtable_validation_score., /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable., /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = P_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = &outtable_gini_validation. /*Dataset that contains the Gini coefficient*/
);

%mend gini_for_set_predictors;
/***********************************************************************************/
