/*********************************************************************************/
/*Replace missing values for all numeric variables with their mean*/
%macro replace_numeric_missing_values(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
numeric_summary, /*Name of table that contains only the character variables that will be in the model*/
/*********************************************************************************/
/*Output*/
output_table /*Name of table that will have the target variable, the ID variable, the weight variable and all the character variables that will be in the model with missing values replaced*/
);
proc sql noprint;
select name into :numeric_variables_to_analyse separated by ' '
from &numeric_summary.
;
quit;
%if %Symexist(numeric_variables_to_analyse)=0 %then %do;
data &output_table.;
	set &input_table. (keep= &target_variable. &id_variable. &weight_variable.) ;
run;
%end;
%else %do;
proc stdize data=&input_table. (keep= &numeric_variables_to_analyse. &target_variable. &id_variable. &weight_variable.) 
	out=&output_table. missing=mean reponly;
  var &numeric_variables_to_analyse.;
run;
%end;
%mend replace_numeric_missing_values;
/*********************************************************************************/
