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
/* Program Name:             ---  find_1_level_chars.sas												*/
/* Description:              ---  Check whether there are predictors with only 1 level. If so, then 
drop these fields. The code is relevant to character variables. 										*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro find_1_level_chars(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset.  
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
output_table, /*Name of output table that will produce a summary for the missing values*/
);
proc contents data=&input_table. (keep=_char_ drop= &target_variable. &id_variable. &weight_variable.) noprint out=&output_table. (keep=label name varnum);
run;
proc sort data=&output_table. out=&output_table. (drop=varnum);
	by varnum;
run;
data _null_;
	set &output_table.;
	call symput ('nvars',strip(put(_n_,8.)));
run;
%do i = 1 %to &nvars.;
%put &i.;
%global freq_var;
data _null_;
	set &output_table.;
	if _n_=&i. then call symput ('freq_var', NAME);
run;
%put &freq_var.;
proc freq data=&input_table. (keep= &freq_var.) noprint;
	tables &freq_var. / out=freq;
run;
data _null_;
	set freq;
	call symput ('n_levels',_n_);
run;
data &output_table.;
	set &output_table.;
	if NAME="&freq_var." then do;
		if &n_levels.>1 then has_1_level=0;
		else has_1_level=1;
	end;
run;
%end;
%mend find_1_level_chars;
/*********************************************************************************/

