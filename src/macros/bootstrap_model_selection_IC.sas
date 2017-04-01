/***************************************************************************************************/
/*Macro that applies bootstrapping and uses information criteria (AIC, BIC) for model selection*/
%macro bootstrap_model_selection_IC(
/*********************************************************************************/
/*Input*/
modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable,  /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
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
predictors_outtable_AIC, /*Table that stores the variables' summary, i.e. how many times they were 
entered in the model, based on AIC*/
predictors_outtable_BIC, /*Table that stores the variables' summary, i.e. how many times they were 
entered in the model, based on BIC*/
summary_outtable_AIC, /*Table that stores the AIC summary*/
summary_outtable_BIC, /*Table that stores the BIC summary*/
gini_outtable_development_AIC, /*Table that stores the Gini coefficients for the development sample using
AIC as the model selection criterion*/
gini_outtable_validation_AIC, /*Table that stores the Gini coefficients for the validation sample using
AIC as the model selection criterion*/
gini_outtable_development_BIC, /*Table that stores the Gini coefficients for the development sample using
BIC as the model selection criterion*/
gini_outtable_validation_BIC, /*Table that stores the Gini coefficients for the validation sample using
BIC as the model selection criterion*/
KS_outtable_development_AIC, /*Table that stores the KS statistics for the development sample using
AIC as the model selection criterion*/
KS_outtable_validation_AIC, /*Table that stores the KS statistics for the validation sample using
AIC as the model selection criterion*/
KS_outtable_development_BIC, /*Table that stores the KS statistics for the development sample using
BIC as the model selection criterion*/
KS_outtable_validation_BIC /*Table that stores the KS statistics for the validation sample using
BIC as the model selection criterion*/
);

proc contents data=&modelling_data_development. out=&modelling_data_development._c noprint;
run;

/***************************************************************************************************/
/*Create the data that will store the information criteria output information*/
/***************************************************************************************************/
data iteration_summary_AIC iteration_summary_BIC;
retain iteration_num;
%do k = 1 %to %sysfunc(countw(&varlist_cont., ' ')) ;
%substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' '))))) = .;
%end;
%do k = 1 %to %sysfunc(countw(&varlist_disc., ' ')) ;
%substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' '))))) = .;
%end;
iteration_num=.;
delete;
;
run;
/***************************************************************************************************/

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

/***************************************************************************************************/
/*Run logistic regression with all the predictors*/
/***************************************************************************************************/
data boot&i.;
	set boot&i.;
	weight_final = &weight_variable. * SamplingWeight;
run;
proc logistic data=boot&i. namelen=200;
      class &varlist_disc. / param=ref ;
    weight weight_final;
      model &target_variable. (event='1') = &varlist_cont. &varlist_disc. / link=logit
            expb
            selection=forward
            slentry=1
            slstay=1
            details
            lackfit
;
ods output ModelBuildingSummary=SUM;
ods output FitStatistics=FIT;
/*ods output BestSubsets=Best_Subsets;*/
/*    output out=development_output p=prob xbeta=logit predprob=(individual crossvalidate);*/
/*	score data=&modelling_data_validation. out=validation_output;*/
run;
/***************************************************************************************************/

data fit_AIC fit_SC;
      set fit;
      if Criterion="AIC" then output fit_AIC;
      if Criterion="SC" then output fit_SC;
run;
/*symbol1 i = join v=star l=32  c = black;*/
/*symbol2 i = join v=circle l = 1 c=black;*/
/*proc gplot data = fit_AIC;*/
/*  plot interceptandcovariates * step;*/
/*run;*/
/*quit;*/
/***************************************************************************************************/
/*Produce summary statistics for AIC*/
/***************************************************************************************************/
proc means data= fit_AIC noprint;
      var interceptandcovariates;
      output out= fit_AIC_min;
run;
data fit_AIC_min;
      set fit_AIC_min;
      where _stat_ = "MIN";
run;
proc sql;
create table fit_AIC_best as
select distinct
      t1.*
from fit_AIC as t1
inner join fit_AIC_min as t2
on t1.interceptandcovariates = t2.interceptandcovariates
;
quit;
DATA _NULL_;
      SET fit_AIC_best;
      CALL SYMPUT('aic_step', PUT(step, 4.));
RUN;
data fit_aic_pool;
      set fit_AIC;
      where step between (&aic_step-2) and (&aic_step+2);
run;
proc sql noprint;
select
      effectentered into :AIC_predictors separated by ' '
from sum
where step<=&AIC_step;
quit;
%put AIC_predictors &AIC_predictors.;
data AIC_temp;
retain iteration_num;
%do k = 1 %to %sysfunc(countw(&AIC_predictors., ' ')) ;
%substr(%sysfunc(compress(%scan(&AIC_predictors., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&AIC_predictors., &k., ' '))))) = 1;
%end;
iteration_num = &i.;
run;
proc append base=iteration_summary_AIC data=AIC_temp force;
run;
proc means data=iteration_summary_AIC noprint;
	output out=iteration_summary_AIC_means (drop=_type_ iteration_num) sum=;
run;
data &predictors_outtable_AIC.;
	set iteration_summary_AIC_means;
%do k = 1 %to %sysfunc(countw(&varlist_cont., ' ')) ;
if missing(%substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' ')))))) then %substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' ')))))=0;
else %substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' '))))) = round(%substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' ')))))/_freq_*100, 0.01);
%end;
%do k = 1 %to %sysfunc(countw(&varlist_disc., ' ')) ;
if missing(%substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' ')))))) then %substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' ')))))=0;
else %substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' '))))) = round(%substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' ')))))/_freq_*100, 0.01);
%end;
run;
proc transpose data=&predictors_outtable_AIC. (drop=_freq_) out=&predictors_outtable_AIC._t (rename=(col1=average_IC));
run;
proc sql;
create table &predictors_outtable_AIC. as
select 
	t1.*
	, &nboots. as number_of_bootstrap_samples
	, case when t2.TYPE=1 then 'numeric' 
		when t2.TYPE=2 then 'character'
	end as variable_type
from &predictors_outtable_AIC._t as t1
left join &modelling_data_development._c as t2
on t1._NAME_ = t2.NAME
order by average_IC desc
;
quit;

%if &i.=1 %then %do;
data &summary_outtable_AIC.;
retain iteration_num;
	set fit_aic_best (rename=(InterceptAndCovariates=AIC));
	iteration_num = &i.;
	keep iteration_num AIC;
run;
%end;
%else %do;
data fit_aic_best_temp;
retain iteration_num;
	set fit_aic_best (rename=(InterceptAndCovariates=AIC));
	iteration_num = &i.;
	keep iteration_num AIC;
run;
proc append base=&summary_outtable_AIC. data=fit_aic_best_temp force;
run;
%end;
/***************************************************************************************************/

/***************************************************************************************************/
/*Calculate Gini coefficient for best AIC model*/
proc logistic data=boot&i. namelen=200;
      class &varlist_disc. / param=ref ;
    weight weight_final;
      model &target_variable. (event='1') = &AIC_predictors. / link=logit
/*            expb*/
/*            selection=forward*/
/*            slentry=1*/
/*            slstay=1*/
/*            details*/
/*            lackfit*/
;
/*ods output ModelBuildingSummary=SUM;*/
/*ods output FitStatistics=FIT;*/
/*ods output BestSubsets=Best_Subsets;*/
    output out=development_AIC_output (keep= &target_variable. weight_final IP_0 IP_1 XP_1) p=prob xbeta=logit predprob=(individual crossvalidate);
	score data=&modelling_data_validation. out=validation_AIC_output (keep= &target_variable. &weight_variable. P_0 P_1);
run;

/*Save Gini coefficient for development sample*/
%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = development_AIC_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = weight_final, /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = IP_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = gini_development_AIC /*Dataset that contains the Gini coefficient*/
);
%if &i.=1 %then %do;
data &gini_outtable_development_AIC.;
retain iteration_num;
	set gini_development_AIC (keep= gini);
	iteration_num = &i.;
run;
%end;
%else %do;
data gini_development_AIC_temp;
retain iteration_num;
	set gini_development_AIC (keep= gini);
	iteration_num = &i.;
run;
proc append base=&gini_outtable_development_AIC. data=gini_development_AIC_temp force;
run;
%end;

/*Save Gini coefficient for validation sample*/
%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = validation_AIC_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable., /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = P_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = gini_validation_AIC /*Dataset that contains the Gini coefficient*/
);
%if &i.=1 %then %do;
data &gini_outtable_validation_AIC.;
retain iteration_num;
	set gini_validation_AIC (keep= gini);
	iteration_num = &i.;
run;
%end;
%else %do;
data gini_validation_AIC_temp;
retain iteration_num;
	set gini_validation_AIC (keep= gini);
	iteration_num = &i.;
run;
proc append base=&gini_outtable_validation_AIC. data=gini_validation_AIC_temp force;
run;
%end;
/***************************************************************************************************/

/***************************************************************************************************/
/*Calculate KS statistic for best AIC model*/
/*Save KS statistic for development sample*/
Proc npar1way data=development_AIC_output edf noprint;
	class &target_variable.;
	var IP_0;
	output out=KS_development_AIC (keep= _D_);
run;
%if &i.=1 %then %do;
data &KS_outtable_development_AIC.;
retain iteration_num;
	set KS_development_AIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
%end;
%else %do;
data KS_development_AIC_temp;
retain iteration_num;
	set KS_development_AIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
proc append base=&KS_outtable_development_AIC. data=KS_development_AIC_temp force;
run;
%end;

/*Save KS statistic for validation sample*/
Proc npar1way data=validation_AIC_output edf noprint;
	class &target_variable.;
	var P_0;
	output out=KS_validation_AIC (keep= _D_);
run;
%if &i.=1 %then %do;
data &KS_outtable_validation_AIC.;
retain iteration_num;
	set KS_validation_AIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
%end;
%else %do;
data KS_validation_AIC_temp;
retain iteration_num;
	set KS_validation_AIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
proc append base=&KS_outtable_validation_AIC. data=KS_validation_AIC_temp force;
run;
%end;
/***************************************************************************************************/



/***************************************************************************************************/
/*Produce summary statistics for BIC*/
/***************************************************************************************************/
/*symbol1 i = join v=star l=32  c = black;*/
/*symbol2 i = join v=circle l = 1 c=black;*/
/*proc gplot data = fit_SC;*/
/*  plot interceptandcovariates * step;*/
/*run;*/
/*quit;*/
proc means data= fit_SC noprint;
      var interceptandcovariates;
      output out= fit_SC_min;
run;
data fit_SC_min;
      set fit_SC_min;
      where _stat_ = "MIN";
run;
proc sql;
create table fit_SC_best as
select distinct
      t1.*
from fit_SC as t1
inner join fit_SC_min as t2
on t1.interceptandcovariates = t2.interceptandcovariates
;
quit;
DATA _NULL_;
      SET fit_SC_best;
      CALL SYMPUT('SC_step', PUT(step, 4.));
RUN;
data fit_SC_pool;
      set fit_SC;
      where step between (&SC_step-2) and (&SC_step+2);
run;
proc sql noprint;
select
      effectentered into :SC_predictors separated by ' '
from sum
where step<=&SC_step;
quit;
%put BIC_predictors &SC_predictors;
data BIC_temp;
retain iteration_num;
%do k = 1 %to %sysfunc(countw(&SC_predictors., ' ')) ;
%substr(%sysfunc(compress(%scan(&SC_predictors., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&SC_predictors., &k., ' '))))) = 1;
%end;
iteration_num = &i.;
run;
proc append base=iteration_summary_BIC data=BIC_temp force;
run;
/*%end;*/
proc means data=iteration_summary_BIC noprint;
	output out=iteration_summary_BIC_means (drop=_type_ iteration_num) sum=;
run;
data &predictors_outtable_BIC.;
	set iteration_summary_BIC_means;
%do k = 1 %to %sysfunc(countw(&varlist_cont., ' ')) ;
if missing(%substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' ')))))) then %substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' ')))))=0;
else %substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' '))))) = round(%substr(%sysfunc(compress(%scan(&varlist_cont., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_cont., &k., ' ')))))/_freq_*100, 0.01);
%end;
%do k = 1 %to %sysfunc(countw(&varlist_disc., ' ')) ;
if missing(%substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' ')))))) then %substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' ')))))=0;
else %substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' '))))) = round(%substr(%sysfunc(compress(%scan(&varlist_disc., &k., ' '), "*")), 1, %sysfunc(min(32, %length(%scan(&varlist_disc., &k., ' ')))))/_freq_*100, 0.01);
%end;
run;
proc transpose data=&predictors_outtable_BIC. (drop=_freq_) out=&predictors_outtable_BIC._t (rename=(col1=average_IC));
run;
proc sql;
create table &predictors_outtable_BIC. as
select 
	t1.*
	, &nboots. as number_of_bootstrap_samples
	, case when t2.TYPE=1 then 'numeric' 
		when t2.TYPE=2 then 'character'
	end as variable_type
from &predictors_outtable_BIC._t as t1
left join &modelling_data_development._c as t2
on t1._NAME_ = t2.NAME
order by average_IC desc
;
quit;

%if &i.=1 %then %do;
data &summary_outtable_BIC.;
retain iteration_num;
	set fit_sc_best (rename=(InterceptAndCovariates=BIC));
	iteration_num = &i.;
	keep iteration_num BIC;
run;
%end;
%else %do;
data fit_sc_best_temp;
retain iteration_num;
	set fit_sc_best (rename=(InterceptAndCovariates=BIC));
	iteration_num = &i.;
	keep iteration_num BIC;
run;
proc append base=&summary_outtable_BIC. data=fit_sc_best_temp force;
run;
%end;

/***************************************************************************************************/
/*Calculate Gini coefficient for best BIC model*/
proc logistic data=boot&i. namelen=200;
      class &varlist_disc. / param=ref ;
    weight weight_final;
      model &target_variable. (event='1') = &SC_predictors. / link=logit
/*            expb*/
/*            selection=forward*/
/*            slentry=1*/
/*            slstay=1*/
/*            details*/
/*            lackfit*/
;
/*ods output ModelBuildingSummary=SUM;*/
/*ods output FitStatistics=FIT;*/
/*ods output BestSubsets=Best_Subsets;*/
    output out=development_BIC_output (keep= &target_variable. weight_final IP_0 IP_1 XP_1) p=prob xbeta=logit predprob=(individual crossvalidate);
	score data=&modelling_data_validation. out=validation_BIC_output (keep= &target_variable. &weight_variable. P_0 P_1);
run;

/*Save Gini coefficient for development sample*/
%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = development_BIC_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = weight_final, /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = IP_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = gini_development_BIC /*Dataset that contains the Gini coefficient*/
);
%if &i.=1 %then %do;
data &gini_outtable_development_BIC.;
retain iteration_num;
	set gini_development_BIC (keep= gini);
	iteration_num = &i.;
run;
%end;
%else %do;
data gini_development_BIC_temp;
retain iteration_num;
	set gini_development_BIC (keep= gini);
	iteration_num = &i.;
run;
proc append base=&gini_outtable_development_BIC. data=gini_development_BIC_temp force;
run;
%end;

/*Save Gini coefficient for validation sample*/
%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = validation_BIC_output, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable., /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = P_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = gini_validation_BIC /*Dataset that contains the Gini coefficient*/
);
%if &i.=1 %then %do;
data &gini_outtable_validation_BIC.;
retain iteration_num;
	set gini_validation_BIC (keep= gini);
	iteration_num = &i.;
run;
%end;
%else %do;
data gini_validation_BIC_temp;
retain iteration_num;
	set gini_validation_BIC (keep= gini);
	iteration_num = &i.;
run;
proc append base=&gini_outtable_validation_BIC. data=gini_validation_BIC_temp force;
run;
%end;
/***************************************************************************************************/

/***************************************************************************************************/
/*Calculate KS statistic for best BIC model*/
/*Save KS statistic for development sample*/
Proc npar1way data=development_BIC_output edf noprint;
	class &target_variable.;
	var IP_0;
	output out=KS_development_BIC (keep= _D_);
run;
%if &i.=1 %then %do;
data &KS_outtable_development_BIC.;
retain iteration_num;
	set KS_development_BIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
%end;
%else %do;
data KS_development_BIC_temp;
retain iteration_num;
	set KS_development_BIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
proc append base=&KS_outtable_development_BIC. data=KS_development_BIC_temp force;
run;
%end;

/*Save KS statistic for validation sample*/
Proc npar1way data=validation_BIC_output edf noprint;
	class &target_variable.;
	var P_0;
	output out=KS_validation_BIC (keep= _D_);
run;
%if &i.=1 %then %do;
data &KS_outtable_validation_BIC.;
retain iteration_num;
	set KS_validation_BIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
%end;
%else %do;
data KS_validation_BIC_temp;
retain iteration_num;
	set KS_validation_BIC (rename=(_D_=KS_statistic));
	iteration_num = &i.;
run;
proc append base=&KS_outtable_validation_BIC. data=KS_validation_BIC_temp force;
run;
%end;
/***************************************************************************************************/

/***************************************************************************************************/

%end;

proc sql noprint;
	drop table &predictors_outtable_AIC._t;
	drop table &predictors_outtable_BIC._t;
	drop table &modelling_data_development._c;
quit;

%mend bootstrap_model_selection_IC;
/***************************************************************************************************/
