/***************************************************************************************************/
/*Macro for transforming a list of character variables to binary variables. This code uses PROC TRANSREG DESIGN.*/
%macro character_to_binary_transreg(
/*********************************************************************************/
/*Input*/
input_table, /*Table that has the character variables that will be convert to binary*/
character_variables_list, /*List of character variables separated by space*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
keep_all_levels, /*Set to 1 to keep all the levels from the character variables and 0 to keep all the levels 
apart from one level which will be the reference level*/
/*********************************************************************************/
/*Output*/
output_design_table, /*Table that has the binary variable only*/
output_contents_table /*Table that has the labels of the binary variables, so that it will be possible to 
reference them later.*/
);

data input;
	set &input_table.;
	binary_var = RAND('BERNOULLI',0.5);
run;

proc transreg data=input design CPREFIX=5;
%if &keep_all_levels. = 0 %then %do;
	model class(&character_variables_list. / SEPARATORS='|' 'x');
%end;
%if &keep_all_levels. = 1 %then %do;
	model class(&character_variables_list. / SEPARATORS='|' 'x' zero=none);
%end;
	id bad_flag transact_id weight;
	output out=&output_design_table. (drop= _type_ _name_ Intercept &character_variables_list.);
run;

proc contents data=&output_design_table. (drop= &target_variable. &id_variable. &weight_variable.) 
	out=&output_contents_table. (keep= NAME LABEL TYPE) noprint;
run;

%mend character_to_binary_transreg;
/***************************************************************************************************/
