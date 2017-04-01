/**********************************************************************************************/
/*Macro that calculates the Gini coefficient from a table that contains the target variable, the score variable and the weight*/
%macro Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable,  /*Name of target variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset /*Dataset that contains the Gini coefficient*/
);
proc freq data=&input_dataset_prob. (keep= &score_variable. &target_variable. &weight_variable.);
table &score_variable.*&target_variable. /noprint measures sparse;
output out = &GINI_outdset. smdrc;
weight &weight_variable.;
run;

data &GINI_outdset.;
set &GINI_outdset.;
gini=_smdrc_*-1;
gini_ase=E_smdrc;
run;
%mend Gini_with_proc_freq;
/***********************************************************************************/
