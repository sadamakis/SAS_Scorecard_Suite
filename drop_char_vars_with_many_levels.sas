/**********************************************************************************************/
/*Drop character variables with number of levels that exceed a set threshold*/
%macro drop_char_vars_with_many_levels(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
intable_num_levels, /*Summary table with all the variables that will be checked and the number of levels*/
n_levels_thres, /*Discard variables that have more levels than this threshold (exclusive)*/
/*********************************************************************************/
/*Output*/
output_table /*Name of output table that has predictors with acceptable number of levels*/
);

proc sql noprint;
select name into: chars_with_acceptable_levels separated by ' '
from &intable_num_levels.
where number_of_levels<=&n_levels_thres.
;
quit;
%put &chars_with_acceptable_levels.;
%put %sysfunc(countw(&chars_with_acceptable_levels.));

data &output_table.;
	set &input_table. (keep= &chars_with_acceptable_levels. &target_variable. &id_variable. &weight_variable.);
run;
%mend drop_char_vars_with_many_levels;


