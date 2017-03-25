/**********************************************************************************************/
/*Calculate missing values for numeric variables*/
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
data input_table (drop = rnd reps);
	set &input_table.;
	rnd = round(&weight_variable.);
	do reps = 1 to rnd;
		output;
	end;
run;
proc means data=input_table noprint;
	output out=input_table_nmiss (drop=_type_ &target_variable. &id_variable. &weight_variable.) nmiss=;
run;
proc transpose data=input_table_nmiss out=input_table_nmiss_t;
run;
data _null_;
	set input_table_nmiss_t;
	if _name_ = '_FREQ_' then call symput('nobs', col1);
run;
data missing_numeric_temp (drop=col1);
format vartype $15.;
	set input_table_nmiss_t (rename=(_name_=name));
	if upcase(name) in ('_FREQ_', "%upcase(&id_variable.)", "%upcase(&target_variable.)") then delete;
	miss = col1;
	nonmiss = &nobs. - col1;
	pctmiss = round(col1/&nobs.*100, 0.01);
	vartype = 'NUMERIC';
run;
proc sort data=missing_numeric_temp out=&output_table.;
	by miss name;
run;
%mend numeric_missing;
/*********************************************************************************/
