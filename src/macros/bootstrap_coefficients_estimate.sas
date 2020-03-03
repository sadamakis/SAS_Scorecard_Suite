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
/* Program Name:             ---  bootstrap_coefficients_estimate.sas									*/
/* Description:              ---  Given a pre-defined set of variables, this macro applies 
bootstrapping to improve parameters' estimates															*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro bootstrap_coefficients_estimate(
/*********************************************************************************/
/*Input*/
modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable,  /*Name of target variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row. This should not be SamplingWeight, 
as this name is reserved in the macro*/
varlist_cont, /*List of continuous variables that will go in the model*/
varlist_disc, /*List of categorical variables that will go in the model*/
nboots, /*Number of bootstrap samples*/
sampling_method, /*srs or urs: sampling method for bootstrapping. srs for simple random selection 
(no replacement), urs for random selection with replacement*/
bootsize, /*Bootstrap sample for 'goods'. In credit risk and fraud the 'bad flag' is undersampled. The bootstrap 
sample selects all the bads and &bootsize. number of goods. This is to decrease the running time of the algorithm, 
which can be very long - typically each bootstrap sample with ~300 variables takes about ~30 mins*/
/*********************************************************************************/
/*Output*/
predictors_coefficients_outtable, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
metrics_outtable_development, /*Table that stores model metrics for the development sample, e.g. the Gini coefficients, log-losses, KS statistics*/
metrics_outtable_validation /*Table that stores model metrics for the validation sample, e.g. the Gini coefficients, log-losses, KS statistics*/
);

      %do i=1 %to &nboots.;
/***************************************************************************************************/
/*Select the sampling method*/
/***************************************************************************************************/
%if &sampling_method = srs %then %do;
/*proc surveyselect method=srs data=&modelling_data_development. out=boot&i. (drop= SelectionProb) seed=%sysevalf(1000+&i.*35) n=&bootsize. noprint stats;*/
/*run;*/
proc surveyselect data=&modelling_data_development.(where=(&target_variable.=0))
	method=SRS sampsize=&bootsize. seed=%sysevalf(1000+&i.*35) stats noprint out=boot&i._goods (drop= SelectionProb);
run;
data boot&i._bads;
	set &modelling_data_development. (where=(&target_variable.=1));
	SamplingWeight = 1;
run;
data boot&i. (drop=weight1);
	set boot&i._goods (rename=(SamplingWeight=weight1))
		boot&i._bads (rename=(SamplingWeight=weight1));
	SamplingWeight = weight1*&weight_variable.;
run;
%end;
%if &sampling_method = urs %then %do;
/*proc surveyselect method=urs data=&modelling_data_development. out=boot&i. seed=%sysevalf(1000+&i.*35) n=&bootsize. noprint stats;*/
/*run;*/
/*data boot&i. (drop= NumberHits ExpectedHits);*/
/*	set boot&i.;*/
/*	SamplingWeight = SamplingWeight*NumberHits;*/
/*run;*/
proc surveyselect data=&modelling_data_development.(where=(&target_variable.=0))
	method=urs sampsize=&bootsize. seed=%sysevalf(1000+&i.*35) stats noprint out=boot&i._goods;
run;
data boot&i._goods (drop= weight1 NumberHits ExpectedHits);
	set boot&i._goods (rename=(SamplingWeight=weight1));
	SamplingWeight = weight1*NumberHits;
run;
data boot&i._bads;
	set &modelling_data_development. (where=(&target_variable.=1));
	SamplingWeight = 1;
run;
data boot&i. (drop=weight1);
	set boot&i._goods (rename=(SamplingWeight=weight1))
		boot&i._bads (rename=(SamplingWeight=weight1));
	SamplingWeight = weight1*&weight_variable.;
run;
%end;
/***************************************************************************************************/
data boot&i.;
	set boot&i.;
	weight_final = &weight_variable. * SamplingWeight;
run;

proc logistic data=boot&i. /*desc*/ noprint outest=predictors_coefficients namelen=200 ;
	class &varlist_disc. / param=ref ;
	weight weight_final;
	model &target_variable. (event='1') = &varlist_cont. &varlist_disc. / link=logit
/*Allow stepwise selection*/
/*		selection=stepwise*/
/*		slentry=&slent.*/
/*		slstay=&slst.*/
/*Allow enter method*/
		selection=none
;
    output out=development_output (keep= &target_variable. weight_final IP_0 IP_1 XP_1) p=prob xbeta=logit predprob=(individual crossvalidate);
	score data=&modelling_data_validation. out=validation_output (keep= &target_variable. &weight_variable. P_0 P_1);
run;

/***************************************************************************************************/
/*Save the predictor's coefficients*/
%if &i.=1 %then %do;
DATA &predictors_coefficients_outtable.;                               
	SET predictors_coefficients;                           
RUN;                                    
%end;
%else %do;
PROC APPEND BASE=&predictors_coefficients_outtable. DATA=predictors_coefficients force; 
RUN;                                    
%end;
/***************************************************************************************************/

/***************************************************************************************************/
/*Save Gini coefficient for development sample*/
%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = development_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = weight_final, /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = IP_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = gini_development /*Dataset that contains the Gini coefficient*/
);
%logloss(
/**************************************************************************/
/*Input*/
input_dataset_prob = development_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = weight_final, /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
predicted_probability = IP_1, /*Predicted probability from the model output*/
eps = 1e-15, /*Correcting factor*/
/**************************************************************************/
/*Output*/
logloss_outdset = logloss_development /*Dataset that contains the Gini coefficient*/
);
data gini_development;
    set gini_development;
    if _n_=1 then set logloss_development(keep=log_loss);
run;

%if &i.=1 %then %do;
data gini_outtable_development;
retain iteration_num;
	set gini_development (keep= gini log_loss);
	iteration_num = &i.;
run;
%end;
%else %do;
data gini_development_temp;
retain iteration_num;
	set gini_development (keep= gini log_loss);
	iteration_num = &i.;
run;
proc append base=gini_outtable_development data=gini_development_temp force;
run;
%end;

/*Save Gini coefficient for validation sample*/
%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = validation_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable., /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = P_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = gini_validation /*Dataset that contains the Gini coefficient*/
);
%logloss(
/**************************************************************************/
/*Input*/
input_dataset_prob = validation_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable., /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
predicted_probability = P_1, /*Predicted probability from the model output*/
eps = 1e-15, /*Correcting factor*/
/**************************************************************************/
/*Output*/
logloss_outdset = logloss_validation /*Dataset that contains the Gini coefficient*/
);
data gini_validation;
    set gini_validation;
    if _n_=1 then set logloss_validation(keep=log_loss);
run;

%if &i.=1 %then %do;
data gini_outtable_validation;
retain iteration_num;
	set gini_validation (keep= gini log_loss);
	iteration_num = &i.;
run;
%end;
%else %do;
data gini_validation_temp;
retain iteration_num;
	set gini_validation (keep= gini log_loss);
	iteration_num = &i.;
run;
proc append base=gini_outtable_validation data=gini_validation_temp force;
run;
%end;
/***************************************************************************************************/

/***************************************************************************************************/
/*Calculate KS statistic for model*/
/*Save KS statistic for development sample*/
Proc npar1way data=development_output edf noprint;
	class &target_variable.;
	var IP_0;
	output out=KS_development (keep= _D_);
run;
%if &i.=1 %then %do;
data KS_outtable_development;
retain iteration_num;
	set KS_development (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
%end;
%else %do;
data KS_development_temp;
retain iteration_num;
	set KS_development (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
proc append base=KS_outtable_development data=KS_development_temp force;
run;
%end;

/*Save KS statistic for validation sample*/
Proc npar1way data=validation_output edf noprint;
	class &target_variable.;
	var P_0;
	output out=KS_validation (keep= _D_);
run;
%if &i.=1 %then %do;
data KS_outtable_validation;
retain iteration_num;
	set KS_validation (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
%end;
%else %do;
data KS_validation_temp;
retain iteration_num;
	set KS_validation (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
proc append base=KS_outtable_validation data=KS_validation_temp force;
run;
%end;
/***************************************************************************************************/

      %end;

proc sql;
create table &metrics_outtable_development. as 
select 
    t1.*
    , t2.*
from gini_outtable_development as t1
left join KS_outtable_development as t2
on t1.iteration_num = t2.iteration_num
;
quit;
proc sql;
create table &metrics_outtable_validation. as 
select 
    t1.*
    , t2.*
from gini_outtable_validation as t1
left join KS_outtable_validation as t2
on t1.iteration_num = t2.iteration_num
;
quit;


%mend bootstrap_coefficients_estimate;
/***************************************************************************************************/
