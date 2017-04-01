/*********************************************************************************/
/*Replace missing values for all character variables in a dataset with a value*/
%macro replace_character_missing_values(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
character_summary, /*Name of table that contains only the character variables that will be in the model*/
argument_missing_value_replace, /*Character that the missing values will be replaced with*/
/*********************************************************************************/
/*Output*/
output_table /*Name of table that will have the target variable, the ID variable, the weight variable and all the character variables that will be in the model with missing values replaced*/
);

/*Select character variables with non-missing values above a specific threshold and more than one level*/
proc sql noprint;
select name into: character_variables_to_analyse separated by ' '
from &character_summary.
;
quit;
%put &character_variables_to_analyse.;
%put %sysfunc(countw(&character_variables_to_analyse.));

data &output_table.;
   set &input_table. (keep= &character_variables_to_analyse. &target_variable. &id_variable. &weight_variable.);
      array change _character_;
      do over change;
      if strip(change)='' or strip(change)='.' then change="&argument_missing_value_replace.";
    end;
run;
%mend replace_character_missing_values;
/**********************************************************************************************/
