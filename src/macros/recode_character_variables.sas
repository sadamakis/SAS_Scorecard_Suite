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
/* Program Name:             ---  recode_character_variables.sas										*/ 
/* Description:              ---  Macro that uses as input a format table to recode character variables	*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro recode_character_variables(
/**************************************************************************/
/*Input*/
input_format_table, /*Table that has the formats that will be used in PROC FORMAT*/
input_dset, /*Name of table that has the variables to be collapsed*/
target_variable, /*The name of the dependent variable (it should be binary)*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
number_of_levels_thres, /*Inclusive threshold. The macro will select only variables with levels below this threshold*/
/**************************************************************************/
/*Output*/
output_format_table /*Table that contains the formatted variables with the target, the weight and the id variables*/
);

proc sql;
create table summary as
select 
	original_name
	, fmtname
	, count(*)
from &input_format_table.
group by original_name, fmtname
having count(*)<=100
;
quit;
proc sql noprint;
select original_name, fmtname 
into :variables_to_recode separated by ' ', :format_name separated by ' '
from summary
;
quit;
proc sql;
create table format_table as 
select
	t1.*
from &input_format_table. as t1
inner join summary as t2
on t1.original_name = t2.original_name
;
quit;

proc format cntlin = format_table; 
run;

/*Recode the original character variables dataset based on the new formats*/
%local varnum;
%let varnum = %sysfunc(countw(&variables_to_recode.));
%put Total number of vars to process: &varnum.;
%local curr_var curr_format;
data &output_format_table.;
	set &input_dset. (keep= &variables_to_recode. &target_variable. &weight_variable. &id_variable.);
	%do i = 1 %to &varnum.;
		%let curr_var = %scan(&variables_to_recode., &i.);
		%let curr_format = %scan(&format_name., &i.);
		%put Iteration &i., variable &curr_var., format &curr_format.;
		&curr_var. = put(strip(&curr_var.),&curr_format..);
	%end;
run;
%mend recode_character_variables;
/**************************************************************************/
