/**************************************************************************/
/*This macro outputs the number of level of a pre-defined list of variables*/
%macro number_of_levels(
/**************************************************************************/
/*Input*/
input_table, /*Table that has the variables the variables that we would like to check the number of levels*/
list_of_variables, /*List of variables of which the number of levels will be produced*/
/**************************************************************************/
/*Output*/
output_format_table, /*Table that contains the format information*/
outtable_num_levels /*Summary table with all the variables that will be checked and the number of levels*/
);

data &output_format_table.;
format start end $500. label $4. fmtname original_name $32. type $1.;
run;

%let number_of_variables = %sysfunc(countw(&list_of_variables.));
%put &number_of_variables.;

%put &list_of_variables.;

proc freq data=&input_table. noprint;
%do i= 1 %to &number_of_variables.;
%let var_i = %scan(&list_of_variables., &i.);
	tables &var_i. /  out=&var_i.;
%end;
run;

data &outtable_num_levels.;
format NAME $32. number_of_levels 8.;
run;

%do i= 1 %to &number_of_variables.;
%let var_i = %scan(&list_of_variables., &i.);
data &var_i. (drop= &var_i. count percent);
format fmtname original_name $32. label $4. start end $500. type $1.;
	set &var_i.;
	retain fmtname original_name;
	label = strip(put(_n_, 8.));
	original_name = "&var_i.";
	if substr(original_name, length(original_name), 1) in ('0','1','2','3','4','5','6','7','8','9') then fmtname=cats(original_name,'p');
	else fmtname = original_name;
	start = strip(&var_i.);
	end = strip(&var_i.);
	type = 'C';
run;
proc append base=&output_format_table. data=&var_i.;
run;
%check_number_of_rows(&var_i.);
data n_levels_temp;
	NAME = "&var_i.";
	number_of_levels = &nlobs.;
run;
data n_levels_temp;
	set n_levels_temp;
	where not(missing(NAME));
run;
proc append base=&outtable_num_levels. data=n_levels_temp force;
run;
%end;

proc sort data=&outtable_num_levels. (where=(not(missing(NAME))));
	by descending number_of_levels;
run;

data &output_format_table.;
	set &output_format_table.;
	where not(missing(fmtname));
run;

%mend number_of_levels;
/**************************************************************************/










