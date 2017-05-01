/***********************************************************************************/
/*Macro that outputs the following 3 pieces of information: */
/*1) Dataset that can be used to plot the ROC curve*/
/*2) Gini coefficient approximation using the trapezoidal rule*/
/*3) Dataset that can be used to plot the actual vs expected bad rate*/
%macro roc_curve_gini_actual_vs_predctd(
/**************************************************************************/
/*Input*/
input_dataset_prob, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable,  /*Name of target variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset*/
score_variable, /*Score variable should be, e.g., scorecard output or predicted probability*/
number_of_groups, /*Score variable will be split in groups using PROC RANK so that actual and predicted 
probabilities will be calculated in each band. The higher the number of groups the better the Gini 
approximation, but the longer the macro will take to run.*/
/**************************************************************************/
/*Output*/
AUC_outdset, /*The dataset that has the values for the area under the curve per bin. This dataset can be 
used to plot the area under the curve. Use the following code to generate the graph:
goptions reset=all;
axis1 label=("False positive rate") order=(0 to 1 by 0.10);
axis2 label=("True positive rate") order=(0 to 1 by 0.10);
proc gplot data=&AUC_outdset.;
      symbol v=dot h=1 interpol=join;
      plot true_positive_rate*false_positive_rate / overlay haxis=axis1 vaxis=axis2;
      title "ROC curve";
run;
*/
GINI_outdset, /*Dataset that contains the Gini coefficient approximation. Trapezoidal rule is used for the approximation.*/
predicted_expected_outdset, /*Output dataset that contains actual and predicted bad rate per score band. 
Use the following code to produce the graph of actual vs expected bad rate per score band:
goptions reset=all;
axis1 label=("Score band") order=(0 to 10 by 1);
axis2 label=("Bad rate") order=(0 to 0.2 by 0.010);
Legend1 value=(color=blue height=1 'Actual bad rate' 'Predicted bad rate');
proc gplot data=&predicted_expected_outdset.;
	symbol v=dot h=1 interpol=join;
	plot (target_actual_prob target_predicted_prob)*sscoreband / overlay legend=legend1 haxis=axis1 vaxis=axis2;
	title "Scorecard performance";
run;
*/
lift_curve_dataset /*Output dataset that will be used to produce the lift curves*/
);

%let score_threshold = %eval(&number_of_groups. - 1);
%let score_threshold_last = 0;

%local max_score_variable;

proc sql noprint;
select max(&score_variable.) into: max_score_variable
from &input_dataset_prob.
;
quit;

data input_table;
	set &input_dataset_prob;
run;

%let by_univariate = %sysfunc(round(100/&number_of_groups., 0.0000001));
proc univariate data=input_table noprint;
	var &score_variable.;
	output out=p pctlpre=P_ pctlpts=0 to 100 by &by_univariate.;
	weight &weight_variable.;
run; 
proc transpose data=p out=pt;
run; 
proc sort data=pt nodupkey force noequals;
	by COL1;
run; 
data pt (drop= numrec);
	set pt;
	numrec+1;
	if numrec=1 then col1 = col1 + 1E-30;
run;
%if %substr(&score_variable., %length(&score_variable.), 1)=0 or 
%substr(&score_variable., %length(&score_variable.), 1)=1 or
%substr(&score_variable., %length(&score_variable.), 1)=2 or
%substr(&score_variable., %length(&score_variable.), 1)=3 or 
%substr(&score_variable., %length(&score_variable.), 1)=4 or 
%substr(&score_variable., %length(&score_variable.), 1)=5 or 
%substr(&score_variable., %length(&score_variable.), 1)=6 or 
%substr(&score_variable., %length(&score_variable.), 1)=7 or 
%substr(&score_variable., %length(&score_variable.), 1)=8 or 
%substr(&score_variable., %length(&score_variable.), 1)=9 %then %do;
	%let var_length = %eval(%length(&score_variable.));
	%let proposed_name=%sysfunc(cats(%substr(&score_variable., 1, &var_length.),z));
%end;
%else %do;
	%let proposed_name=&score_variable.;
%end;
data cntlin;
format fmtname $32.;
	set pt end=eof;
	length HLO SEXCL EEXCL $1 LABEL $3;
	retain fmtname "&proposed_name." type 'N' end; 
	nrec+1;
	if nrec=1 then do; 
	HLO='L'; SEXCL='N'; EEXCL='Y'; start=.; end=COL1;
	label=put(nrec-1,z2.); output;
	end;
	else if not eof then do;
	HLO=' '; SEXCL='N'; EEXCL='Y'; start=end; end=COL1;
	label=put(nrec-1,z2.); output;
	end;
	else if eof then do;
	HLO='H'; SEXCL='N'; EEXCL='N'; start=end; end=.;
	label=put(nrec-1,z2.); output;
	end;
run;
proc format cntlin=cntlin;
run; 
data rank1;
	set input_table;
	sscoreband = input(put(&score_variable., &proposed_name..), 8.);
/*	sscoreband = put(&score_variable., &proposed_name..);*/
run;

/*proc rank data=input_table */
/*      out=rank1 groups = &number_of_groups.;*/
/*      var &score_variable.;*/
/*      ranks sscoreband;*/
/*run;*/

proc sql;
create table rank1_fixdeciles as 
select 
      sscoreband 
      , sum(&weight_variable.) as number_of_cases
      , sum(&target_variable.*&weight_variable.) as number_of_responses
      , sum(&target_variable.*&weight_variable.)/sum(&weight_variable.) as target_actual_prob
      , sum(&score_variable.*&weight_variable.)/sum(&weight_variable.) as target_predicted_prob
from rank1
group by sscoreband
order by sscoreband
;

proc means data=rank1 (keep= &target_variable. sscoreband &score_variable. &weight_variable.)  min max mean nway noprint;
	class sscoreband;
	var &score_variable.;
	output out=rank1_means(drop=_type_ _freq_)
	min=target_predicted_prob_min
	max=target_predicted_prob_max
	mean=target_predicted_prob_mean;
	weight &weight_variable.;
run;
proc sql;
create table &predicted_expected_outdset. as 
select 
	monotonic() as n
	, t1.*
	, t2.target_predicted_prob_min label=''
	, t2.target_predicted_prob_max label=''
	, t2.target_predicted_prob_mean label=''
from Rank1_fixdeciles as t1
left join rank1_means as t2
on t1.sscoreband = t2.sscoreband
;
quit;

proc sql noprint;
select max(n) into: max_n
from &predicted_expected_outdset.
;
quit;

data predicted_expected_rev;
	set &predicted_expected_outdset.;
	reversed_n = &max_n. - n + 1;
run;
proc sort data=predicted_expected_rev;
	by reversed_n;
run;

data predicted_expected_sum;
	set predicted_expected_rev;
	by reversed_n;
	cumulative_number_of_responses + number_of_responses;
	cumulative_number_of_cases + number_of_cases;
	if last.reversed_n then do;
		call symput('total_responses',cumulative_number_of_responses);
		call symput('total_cases',cumulative_number_of_cases);
	end;
run;

data &lift_curve_dataset.;
	set predicted_expected_sum;
	percent_of_events = number_of_responses / &total_responses.;
	cumulative_percent_of_events = cumulative_number_of_responses / &total_responses.;
	percent_of_cases = number_of_cases / &total_cases.;
	lift = percent_of_events / percent_of_cases;
	cumulative_percent_of_cases = cumulative_number_of_cases / &total_cases.;
	cumulative_lift = cumulative_percent_of_events / cumulative_percent_of_cases;
run;

proc sql noprint;
select sscoreband into: all_scoreband separated by '|'
from rank1_fixdeciles
;
quit;
%put &all_scoreband.;

data &AUC_outdset.;
format score_threshold 8. true_positive_rate 8.4 false_positive_rate 8.4;
run;

%let i=1;

%do %while (%scan(&all_scoreband., &i., '|') ne );

proc sql;
create table roc_curves as 
select
%scan(&all_scoreband., &i., '|') as score_threshold
, sum(case when sscoreband>%scan(&all_scoreband., &i., '|') and &target_variable.=1 then 1 else 0 end) / (sum(case when sscoreband>%scan(&all_scoreband., &i., '|') and &target_variable.=1 then 1 else 0 end) + sum(case when sscoreband<=%scan(&all_scoreband., &i., '|') and &target_variable.=1 then 1 else 0 end)) as true_positive_rate
, 1 - sum(case when sscoreband<=%scan(&all_scoreband., &i., '|') and &target_variable.=0 then 1 else 0 end) / (sum(case when sscoreband<=%scan(&all_scoreband., &i., '|') and &target_variable.=0 then 1 else 0 end) + sum(case when sscoreband>%scan(&all_scoreband., &i., '|') and &target_variable.=0 then 1 else 0 end)) as false_positive_rate
from rank1
;
quit;

proc append base=&AUC_outdset. data=roc_curves;
run;

%let i = %eval(&i.+1);

%end;

data &AUC_outdset.;
      set &AUC_outdset.;
      if missing(score_threshold) then delete;
run;

data &AUC_outdset.1;
format score_threshold 8. true_positive_rate 8.4 false_positive_rate 8.4;
      score_threshold = &score_threshold.;
      true_positive_rate = 0;
      false_positive_rate = 0;
      output;
run;
data &AUC_outdset.l;
format score_threshold 8. true_positive_rate 8.4 false_positive_rate 8.4;
      score_threshold = &score_threshold_last.;
      true_positive_rate = 1;
      false_positive_rate = 1;
      output;
run;

proc append base=&AUC_outdset. data=&AUC_outdset.1;
run;
proc append base=&AUC_outdset. data=&AUC_outdset.l;
run;
proc sort data=&AUC_outdset.;
      by descending score_threshold;
run;
data &AUC_outdset.;
      set &AUC_outdset.;
      AUC_i = (true_positive_rate + lag(true_positive_rate))*(false_positive_rate - lag(false_positive_rate)) / 2;
      if missing(AUC_i) then delete;
run;
data &GINI_outdset.;
      set &AUC_outdset. nobs=last;
      retain AUC;
      AUC + AUC_i;
      if _n_ = last then do;
            Gini = 2*AUC-1;
            put 'Gini = ' Gini;
            output;
      end;
      keep AUC Gini;
run;

proc sql noprint;
   drop table &AUC_outdset.1;
   drop table &AUC_outdset.l;
quit;

%mend roc_curve_gini_actual_vs_predctd;
/***********************************************************************************/
