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
/* Program Name:             ---  drop_char_vars_with_many_levels.sas									*/
/* Description:              ---  Drop character variables with number of levels that exceed a set 
threshold																								*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
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


