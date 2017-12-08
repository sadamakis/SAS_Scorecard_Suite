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
/* Program Name:             ---  replace_numeric_missing_values_with_mean.sas							*/ 
/* Description:              ---  Replace missing values for all numeric variables with their mean		*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro replace_numeric_missing_values(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the numeric variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
numeric_summary, /*Name of table that contains only the character variables that will be in the model*/
replace_percentage, /*Takes values 0-100. Replace missing values with mean for all variables that missing percentage
is below this threshold. For numeric variables with missing percentage above this threshold, the missing
values are left as missing.*/
/*********************************************************************************/
/*Output*/
output_table /*Name of table that will have the target variable, the ID variable, the weight variable and all the character variables that will be in the model with missing values replaced*/
);
proc sql noprint;
select name into :numeric_variables_to_replace separated by ' '
from &numeric_summary.
where pctmiss <= &replace_percentage.
;
quit;
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
  var &numeric_variables_to_replace.;
run;
%end;
%mend replace_numeric_missing_values;
/*********************************************************************************/
