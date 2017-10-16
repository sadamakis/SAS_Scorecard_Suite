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
/* Program Name:             ---  green.sas																*/
/* Description:              ---  Group levels based on: Comparison of Data Preparation Methods for Use 
in Model Development with SAS Enterprise Miner (http://www2.sas.com/proceedings/sugi31/079-31.pdf)
This method of collapsing nominal predictors (using any-pairs collapsing) is based on clustering of levels 
using SAS PROC CLUSTER. This method selects the pair for collapsing which maximizes the Pearson chi-square. 
A stopping criterion is defined by selecting the iteration which produces the minimum chi-square statistic 
probability (right tail probability) of association between the target and the collapsed predictor. 	*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro green(
/**************************************************************************/
/*Input*/
dtstp, /*name of input dataset that contains the class variable and the target variable*/
clv, /*name of character variable that the levels should be collapsed*/
target_var, /*name of the target variable*/
/**************************************************************************/
/*Output*/
output_format_table_temp /*Dataset that stores the format of the variables that will need to be recoded. 
This will be used in PROC FORMAT.*/
);

dm 'clear lst';
%put The class variable is &clv. and the target variable is &target_var.;
 proc means data = &dtstp nway noprint; var &target_var.;
class &clv ;
output out = levelspp mean = prop;
 run;
 %check_number_of_rows(
/**************************************************************************/
/*Input*/
levelspp /*Name of table to check*/
);
%put The number of levels in &clv. are &nlobs.;

%if &dsid.>0 and &nlobs.>2 %then %do;
ods trace on /listing;
 proc cluster data = levelspp method = ward outtree = fortree noprint;
freq _freq_;
var prop;
id &clv ;
run;
ods trace off;
ods listing close;
ods output clusterhistory = cluster;
 proc cluster data = levelspp method = ward;
freq _freq_;
var prop;
id &clv;
run;
ods listing;
proc freq data = &dtstp (keep= &clv &target_var.) noprint;
table &clv * &target_var./chisq;
output out = chi(keep = _pchi_) chisq;
run;
data cutoff;
if _N_ = 1 then set chi;
set cluster;
chisquare = _pchi_*rsquared;
degfree = numberofclusters - 1;
logpval = logsdf('CHISQ',chisquare,degfree);
run;
proc means data = cutoff noprint;
var logpval;
output out = clusop minid(logpval(numberofclusters))= ncl;
run;
data null;
set clusop;
call symput ('ncl',ncl);
run;
proc tree data = fortree nclusters = &ncl out = clus h= rsq noprint; 
	id &clv ;
run;
proc sort data = clus ; 
	by clusname;
run;

data format_c;
	set Clus (keep= &clv. CLUSNAME rename=(&clv.=start CLUSNAME=label));
	fmtname = "&clv.";
	type='C';
run;

proc append base=&output_format_table_temp. data=format_c force;
run;

proc sql;
create table &output_format_table_temp. as 
select distinct * 
from &output_format_table_temp.
order by fmtname, label, start
;
quit;
%end;

*end greenacre ;
%mend green;
/**********************************************************************************************/
