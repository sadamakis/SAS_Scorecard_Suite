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
/* Program Name:             ---  numeric_missing.sas													*/ 
/* Description:              ---  Calculate missing values for numeric variables						*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro numeric_missing(
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
proc contents data=&input_table. (keep=_numeric_ drop= &target_variable. &id_variable. &weight_variable.) noprint 
	out=content_num (keep=label name varnum);
run;
proc sort data=content_num out=content_num (drop=varnum);
	by varnum;
run;
data _null_;
	set content_num;
	call symput ('nvars',strip(put(_n_,8.)));
run;
proc sql noprint;
select NAME into: variables_all separated by ' '
from content_num 
;
quit;

proc sql;
create table input_table_nmiss as 
select 
	sum(&weight_variable.) as totobs
%do i= 1 %to &nvars.;
%let variable_i = %scan(&variables_all., &i.);
	, sum(case when &variable_i. is null then &weight_variable. else 0 end) as &variable_i.
%end;
from &input_table.
;
quit;

proc transpose data=input_table_nmiss out=input_table_nmiss_t;
run;
data _null_;
	set input_table_nmiss_t;
	if _name_ = 'totobs' then call symput('nobs', col1);
run;
data missing_numeric_temp (drop=col1);
format vartype $15.;
	set input_table_nmiss_t (rename=(_name_=name));
	if upcase(name) in ('TOTOBS') then delete;
	miss = round(col1, 0.01);
	nonmiss = round(&nobs. - col1, 0.01);
	pctmiss = round(col1/&nobs.*100, 0.01);
	vartype = 'NUMERIC';
run;
proc sql;
create table &output_table. as 
select
	t1.vartype
	, t2.NAME
	, t2.LABEL
	, t1.miss
	, t1.nonmiss
	, t1.pctmiss
from missing_numeric_temp as t1
left join Content_num as t2
on t1.name = t2.NAME
order by miss, name
;
quit;
%mend numeric_missing;
/*********************************************************************************/
