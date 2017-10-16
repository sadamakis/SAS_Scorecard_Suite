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
/* Program Name:             ---  replace_character_missing_values.sas									*/ 
/* Description:              ---  Replace missing values for all character variables in a dataset with 
a value																									*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
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
