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
/* Program Name:             ---  character_missing.sas													*/
/* Description:              ---  Calculate missing values for character variables						*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro character_missing(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
output_table /*Name of output table that will produce a summary for the missing values*/
);
proc contents data=&input_table. (keep=_char_ drop= &target_variable. &id_variable. &weight_variable.) noprint out=content_char (keep=label name varnum);
run;
proc sort data=content_char out=content_char (drop=varnum);
	by varnum;
run;
data _null_;
	set content_char;
	call symput ('nvars',strip(put(_n_,8.)));
run;
proc sql noprint;
select sum(&weight_variable.) into :totobs
from &input_table. (keep= &weight_variable.)
;
quit;
data &output_table.;
	set &input_table. (keep= _char_ &weight_variable.) nobs=totobs end=last;
	array char1(*) _char_;
	array count_miss(&nvars) /*count_nmiss(&nvars)*/;
	do i = 1 to dim(char1);
	if char1(i)='' then count_miss(i) + &weight_variable.;
/*	else count_nmiss(i) + &weight_variable.;*/
	end;
	if last then do i = 1 to dim(char1);
		set content_char point=i;
		miss = round(sum(count_miss(i),0), 0.01);
		nonmiss = round(&totobs. - miss, 0.01);
		pctmiss = round((miss / &totobs.) * 100, 0.01);
		output;
	end;
	keep name label miss nonmiss pctmiss; 
run;
data &output_table.;
format vartype $15.;
	set &output_table.;
	vartype = 'CHARACTER';
run;
proc sort data=&output_table.;
	by pctmiss NAME;
run;
%mend character_missing;
/*********************************************************************************/
