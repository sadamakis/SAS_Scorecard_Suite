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
/* Program Name:             ---  variable_reduction.sas												*/
/* Description:              ---  Variable reduction using PROC VARCLUS									*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro variable_reduction(
/*********************************************************************************/
/*Input*/
input_dset, /*The name of the dataset that contain all the numeric variables*/
numeric_vars, /*List of numeric variables that should be reduced*/
maxeigen, /*Argument in PROC VARCLUS. The largest permissible value of the second eigenvalue in each cluster. 
The lower the value	the more splits will be performed.*/
target_variable, /*The name of the dependent variable (it should be binary)*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/*********************************************************************************/
/*Output*/
out_dset_one_var_per_cluster, /*The output dataset that provides the list of variables that can be used for modelling. 
	The code keeps only one variable from every cluster - the variable that has the minimum 1-Rsquare. 
	The lower the 1-Rsquare is the higher the variance explained by that variable in the cluster and the 
	lower variable explained in other clusters.*/
out_dset_all_vars, /*The output dataset that has the result of PROC VARCLUS and the p-values from the 
	two sample t-tests.*/
varclus_ttest /*The output dataset that has a summary of the VARCLUS output and the t-test output*/
); 

ods select none;
ods output ClusterQuality=ClusterQuality
           RSquare=RSquare
			ClusterSummary=ClusterSummary
			ConvergenceStatus=ConvergenceStatus
			DataOptSummary=DataOptSummary
;

proc varclus data=&input_dset maxeigen=&maxeigen. /*outtree=tree*/ short hi;
   var &numeric_vars;
   weight &weight_variable.;
run;
ods select all;

data _null_;
set ClusterQuality;
call symput('nvar',compress(NumberOfClusters));
run;

data selvars;
set RSquare (where = (NumberOfClusters=&nvar));
keep Cluster Variable RSquareRatio;
run;

data cv / view=cv;
retain dummy 1;
set selvars;
keep dummy cluster;
run;

data filled;
update cv(obs=0) cv;
by dummy;
set selvars(drop=cluster);
output;
drop dummy;
run;

proc sort data = filled;
by cluster RSquareRatio;
run;

data &out_dset_one_var_per_cluster;
set filled (rename = (variable = Best_Variables));
if first.cluster then output;
by cluster;
run;
/*****************************************************************************************/

/*****************************************************************************************/
/*When in doubt which of the highly correlated variables to drop then do two sample t-tests to select the 
variable that is more correlated with the dependent variable*/
ods output "Statistics" = Statistics
 "T-Tests" = ttests
 "Equality of Variances" = equality_of_variances;
ods graphics off;
proc ttest data=&input_dset. (keep= &numeric_vars. &target_variable. &weight_variable.);
	class &target_variable.;
	var &numeric_vars.;
	weight &weight_variable.;
run;
ods graphics on;
ods output close; 
data Ttests_equal_variance Ttests_unequal_variance;
	set Ttests;
	if variances='Equal' then output Ttests_equal_variance;
	else output Ttests_unequal_variance;
run;
proc sort data=Ttests_equal_variance;
	by variable;
run;
proc sort data=Ttests_unequal_variance;
	by variable;
run;
/*****************************************************************************************/

/*****************************************************************************************/
/*Get the mean and standard deviation from every variable*/
proc means data=&input_dset. (keep= &numeric_vars. &weight_variable.) noprint;
	output out=means (drop=_type_ _freq_) mean=;
	weight &weight_variable.;
run;
proc transpose data=means out=means_t;
run;
proc means data=&input_dset. (keep= &numeric_vars. &weight_variable.) noprint;
	output out=standard_deviation (drop=_type_ _freq_) std=;
	weight &weight_variable.;
run;
proc transpose data=standard_deviation out=standard_deviation_t;
run;
/*****************************************************************************************/

/*****************************************************************************************/
/*Merge the information from VARCLUS and from correlation with the dependant variable*/
proc sql;
create table &varclus_ttest. as 
select 
	t1.*
	, case when t4.ProbF<0.05 then t3.tValue else t2.tValue end as tValue format 7.2
	, case when t4.ProbF<0.05 then t3.DF else t2.DF end as DF format BEST6.
	, case when t4.ProbF<0.05 then t3.Probt else t2.Probt end as Probt format PVALUE6.4
	, case when t4.ProbF<0.05 then -log(t3.Probt) else -log(t2.Probt) end as minus_log_Probt
	, t5.COL1 as mean format 7.3
	, t6.COL1 as standard_deviation format 7.3
from filled as t1
left join Ttests_equal_variance as t2
on t1.Variable = t2.Variable
left join Ttests_unequal_variance as t3
on t1.Variable = t3.Variable
left join equality_of_variances as t4
on t1.Variable = t4.Variable
left join Means_t as t5
on t1.Variable = t5._NAME_
left join Standard_deviation_t as t6
on t1.Variable = t6._NAME_
order by t1.Cluster, t1.RSquareRatio, calculated Probt
;
quit;

proc sql;
create table varclus_ttest_sum as 
select
	cluster
	, avg(minus_log_Probt) as avg_minus_log_Probt format 7.2
	, avg(abs(tValue)) as avg_tValue format 7.2
from &varclus_ttest.
group by cluster
;
quit;

proc sql;
create table &out_dset_all_vars. as 
select 
	t1.cluster
	, t1.variable
	, t1.RSquareRatio
	, t1.mean
	, t1.standard_deviation
/*	,  minus_log_Probt/avg_minus_log_Probt */
	,  case when minus_log_Probt is not null then minus_log_Probt/avg_minus_log_Probt 
		else abs(tValue)/avg_tValue end 
		as importance_weight format 7.2
from &varclus_ttest. as t1
left join varclus_ttest_sum as t2
on t1.cluster = t2.cluster
;
quit;
/*****************************************************************************************/

%mend variable_reduction;
/****************************************************************************************/
