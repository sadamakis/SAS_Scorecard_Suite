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
predicted_expected_outdset /*Output dataset that contains actual and predicted bad rate per score band. 
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
);

%let score_threshold = %eval(&number_of_groups. - 1);
%let score_threshold_last = 0;

proc rank data=&input_dataset_prob. 
      out=rank1 groups = &number_of_groups.;
      var &score_variable.;
      ranks sscoreband;
run;

proc sql;
create table rank1_fixdeciles as 
select 
      sscoreband 
      , count(*) as vol_sum
      , sum(&target_variable.) as target_variable_sum
      , sum(&target_variable.)/count(*) as target_actual_prob
      , sum(&score_variable.)/count(*) as target_predicted_prob
from rank1
group by sscoreband
order by sscoreband
;

proc means data=rank1 (keep= &target_variable. sscoreband &score_variable.)  min max mean nway noprint;
	class sscoreband;
	var &score_variable.;
	output out=rank1_means(drop=_type_ _freq_)
	min=target_predicted_prob_min
	max=target_predicted_prob_max
	mean=target_predicted_prob_mean;
run;
proc sql;
create table &predicted_expected_outdset. as 
select 
	monotonic() as n
	, t1.*
	, t2.target_predicted_prob_min
	, t2.target_predicted_prob_max
	, t2.target_predicted_prob_mean
from Rank1_fixdeciles as t1
left join rank1_means as t2
on t1.sscoreband = t2.sscoreband
;
quit;

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
