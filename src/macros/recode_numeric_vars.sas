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
/* Program Name:             ---  recode_numeric_vars.sas												*/ 
/* Description:              ---  Macro that recodes the original numeric variables dataset based on 
the variable reduction method																			*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro recode_numeric_vars(
/*********************************************************************************/
/*Input*/
input_dset, /*The name of the dataset that contain all the numeric variables*/
target_variable, /*The name of the dependent variable (it should be binary)*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset /*Dataset that has the numeric variables transformed*/
);

%if &argument_transform. ne dominant %then %do;

%if &argument_transform.=standardised %then %do;
data &coded_vars_dset.;
format argument $1000.;
	set &variable_reduction_output_dset.;
	by cluster;
	retain argument;
%if &argument_function.=min %then %do;
	if first.cluster then do;
		argument = '(1E7,';
	end;
%end;
%else %if &argument_function.=max %then %do;
	if first.cluster then do;
		argument = '(-1E7,';
	end;
%end;
%else %if &argument_function.=mean %then %do;
	if first.cluster then do;
		argument = '(';
	end;
%end;
%else %do;
%put ERROR: The argument function is not supported;
%end;
/*Use the following for minimum of all the standardised variables*/
	argument = cats(argument,'(',variable,'-',round(mean, 0.001),')','/',round(standard_deviation,0.001),',');
	cluster = compress(cluster);
	if last.cluster then do;
		argument = cats(substr(argument,1,length(argument)-1),')');
		output;
	end;
	keep argument cluster;
run;
%end;
%else %if &argument_transform.=importance_weight %then %do;
data &coded_vars_dset.;
format argument $1000.;
	set &variable_reduction_output_dset.;
	by cluster;
	retain argument;
%if &argument_function.=min %then %do;
	if first.cluster then do;
		argument = '(1E7,';
	end;
%end;
%else %if &argument_function.=max %then %do;
	if first.cluster then do;
		argument = '(-1E7,';
	end;
%end;
%else %if &argument_function.=mean %then %do;
	if first.cluster then do;
		argument = '(';
	end;
%end;
%else %do;
%put ERROR: The argument function is not supported;
%end;
/*Use the following for minimum of all the importance_weight*variables*/
	argument = cats(argument,round(importance_weight,0.0001),'*',variable,',');
	cluster = compress(cluster);
	if last.cluster then do;
		argument = cats(substr(argument,1,length(argument)-1),')');
		output;
	end;
	keep argument cluster;
run;
%end;
%else %if &argument_transform.=importance_weight_standardised %then %do;
data &coded_vars_dset.;
format argument $1000.;
	set &variable_reduction_output_dset.;
	by cluster;
	retain argument;
%if &argument_function.=min %then %do;
	if first.cluster then do;
		argument = '(1E7,';
	end;
%end;
%else %if &argument_function.=max %then %do;
	if first.cluster then do;
		argument = '(-1E7,';
	end;
%end;
%else %if &argument_function.=mean %then %do;
	if first.cluster then do;
		argument = '(';
	end;
%end;
%else %do;
%put ERROR: The argument function is not supported;
%end;
/*Use the following for minimum of all the importance_weight* standardised variables*/
	argument = cats(argument,round(importance_weight,0.001),'*(',variable,'-',round(mean, 0.001),')','/',round(standard_deviation,0.001),',');
	cluster = compress(cluster);
	if last.cluster then do;
		argument = cats(substr(argument,1,length(argument)-1),')');
		output;
	end;
	keep argument cluster;
run;
%end;
%else %if &argument_transform.=no_transform %then %do;
data &coded_vars_dset.;
format argument $1000.;
	set &variable_reduction_output_dset.;
	by cluster;
	retain argument;
%if &argument_function.=min %then %do;
	if first.cluster then do;
		argument = '(1E7,';
	end;
%end;
%else %if &argument_function.=max %then %do;
	if first.cluster then do;
		argument = '(-1E7,';
	end;
%end;
%else %if &argument_function.=mean %then %do;
	if first.cluster then do;
		argument = '(';
	end;
%end;
%else %do;
%put ERROR: The argument function is not supported;
%end;
/*Use the following for minimum of all the variables*/
	argument = cats(argument,variable,',');
	cluster = compress(cluster);
	if last.cluster then do;
		argument = cats(substr(argument,1,length(argument)-1),')');
		output;
	end;
	keep argument cluster;
run;
%end;
%else %do;
%put ERROR: There is no valid argument for variables transformation;
%end;

proc sql noprint;
select distinct cluster, argument 
into :cluster separated by '|', :argument separated by '|'
from &coded_vars_dset.
;
quit;
%put &cluster.;
%put &argument.;

%local varnum;
proc sql noprint;
select count(*)	into :varnum
from &coded_vars_dset.
;
quit;
%put Total number of coded variables to process: &varnum;
%local curr_code;
data &output_dset.;
	set &input_dset.;
	%do i = 1 %to &varnum;
		%let cluster_i = %scan(&cluster, &i, '|');
		%let argument_i = %scan(&argument, &i, '|');
		%put Iteration &i., cluster &cluster_i., argument &argument_i.;
		&cluster_i. = &argument_function.&argument_i.;
		keep &cluster_i.;
	%end;
%if &argument_function.=min %then %do;
	if &cluster_i.=1E7 then &cluster_i.=.;
%end;
%else %if &argument_function.=max %then %do;
	if &cluster_i.=-1E7 then &cluster_i.=.;
%end;
	keep &weight_variable. &target_variable. &id_variable.;
run;

%end;

%else %if &argument_transform.=dominant %then %do;

proc sort data=&variable_reduction_output_dset. out=variable_reduction_s;
	by cluster importance_weight descending RSquareRatio;
run;
data variable_reduction_s;
	set variable_reduction_s;
	by cluster;
	if last.cluster then output;
run;
proc sql noprint;
select variable into :dominant_vars_within_cluster separated by ' '
from variable_reduction_s
;
quit;
%put The dominant variables within each cluster are &dominant_vars_within_cluster.;
data &output_dset.;
	set &input_dset. (keep= &target_variable. &weight_variable. &id_variable. &dominant_vars_within_cluster.);
run;

%end;

%mend;
/****************************************************************************************/
