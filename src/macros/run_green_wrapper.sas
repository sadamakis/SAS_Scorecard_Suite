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
/* Program Name:             ---  run_green_wrapper.sas													*/
/* Description:              ---  Run the green macro for all the character variables in the dataset	*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro run_green_wrapper(
/**************************************************************************/
/*Input*/
input_dset, /*Name of table that has the variables to be collapsed*/
variables_to_recode, /*List of variables that will be collapsed*/
target_variable, /*The name of the dependent variable (it should be binary)*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/**************************************************************************/
/*Output*/
output_format_table, /*Table that contains the format information*/
output_formatted_data /*Table that contains the recoded variables*/
);

/*Expand the dataset to take into account the weights*/
data input_table (drop = rnd reps);
	set &input_dset.;
	rnd = round(&weight_variable.);
	do reps = 1 to rnd;
		output;
	end;
run;

data &output_format_table.;
format start $500. label $80. fmtname $32. type $1.;
run;

%let i=1;
%do %while (%scan(&variables_to_recode.,&i.) ne );
%put Collapse levels for variable %scan(&variables_to_recode.,&i.);
%green(clv=%scan(&variables_to_recode.,&i.), dtstp=input_table, target_var=&target_variable., output_format_table_temp=&output_format_table.);
%let i = &i.+1;
%end;

%check_number_of_rows(
/**************************************************************************/
/*Input*/
&output_format_table. /*Name of table to check*/
);
%put The number of rows in the format table are &nlobs.;

%if &dsid.>0 and &nlobs.>1 %then %do;

data &output_format_table.;
	set &output_format_table.;
	where not(missing(fmtname));
run;

/*Create a format table*/
data &output_format_table.;
format fmtname $33.;
	set &output_format_table. (rename=(fmtname=original_name));
	if substr(original_name, length(original_name), 1) in ('0','1','2','3','4','5','6','7','8','9') then fmtname=cats(original_name,'p');
	else fmtname = original_name;
run;

proc format cntlin = &output_format_table.; 
run;

proc sql noprint;
select distinct fmtname, original_name 
	into :format_name separated by ' ', :char_variables_original_name separated by ' '
from &output_format_table.
;
quit;

/*Recode the original character variables dataset based on the new formats*/
%local varnum;
%let varnum = %sysfunc(countw(&char_variables_original_name));
%put Total number of vars to process: &varnum;
%local curr_var curr_fomat;
data &output_formatted_data.;
	set &input_dset.;
	%do i = 1 %to &varnum;
		%let curr_var = %scan(&char_variables_original_name, &i);
		%let curr_format = %scan(&format_name, &i);
		%put Iteration &i., variable &curr_var., format &curr_format.;
		&curr_var = put(&curr_var,&curr_format..);
	%end;
run;

%end;

%else %do;
data &output_formatted_data.;
	set &input_dset.;
run;
%end;

%mend run_green_wrapper;
/**************************************************************************/
