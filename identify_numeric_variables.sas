/**********************************************************************************************/
/*Identify numeric variables from a dataset*/
%macro identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
);
%GLOBAL &numeric_variables.;

%let &numeric_variables. = ;
proc contents data=&input_table. (drop= &target_variable. &id_variable. &weight_variable.) noprint out=content_dset (keep=label name varnum TYPE);
run;
proc sql noprint;
select name into :&numeric_variables. separated by ' '
from content_dset
where TYPE=1
;
quit;
%mend identify_numeric_variables;
/**********************************************************************************************/
