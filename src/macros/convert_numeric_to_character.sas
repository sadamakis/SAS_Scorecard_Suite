/**************************************************************************/
/*Macro that converts all the numeric fields to character fields*/
%macro convert_numeric_to_character(
/**************************************************************************/
/*Input*/
input_dset, /*Input table that contains the numeric variables that should be converted to character*/
target_variable, /*The name of the dependent variable (it should be binary)*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
character_format, /*Format inside the PUT statement*/
/**************************************************************************/
/*Output*/
output_dset /*Name of table that the numeric variables are converted to character*/
);

/*Set the data that contain the target variable and the predictors*/
data input_table;
	set &input_dset.;
run;

proc contents data=input_table (drop= &id_variable. &target_variable. &weight_variable.) out=numeric_contents noprint;
run;
proc sql noprint;
select NAME, cats(substr(NAME, 1 , length(NAME)-1),'r')
into :original_name separated by ' ', :rename_name separated by ' '
from numeric_contents
;
quit;
%put The original name of the variables are: &original_name.;
%put The original variables will be temporarily renamed to: &rename_name.;
%put %sysfunc(countw(&rename_name.));

data &output_dset.
(drop=
%do i=1 %to %sysfunc(countw(&original_name.));
%let renm_name=%scan(&rename_name.,&i.);
	&renm_name.
%end;
)
;
	set &input_dset.
(rename=(
%do i=1 %to %sysfunc(countw(&original_name.));
%let orignl_name=%scan(&original_name.,&i.);
%let renm_name=%scan(&rename_name.,&i.);
	&orignl_name.=&renm_name.
%end;
))
;
%do i=1 %to %sysfunc(countw(&original_name.));
%let orignl_name=%scan(&original_name.,&i.);
%let renm_name=%scan(&rename_name.,&i.);
	&orignl_name. = strip(put(&renm_name., &character_format.));
%end;
run;
%mend convert_numeric_to_character;
/**************************************************************************/
