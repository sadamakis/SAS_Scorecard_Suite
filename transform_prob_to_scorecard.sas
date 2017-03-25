/**********************************************************************************************/
/*Transform probabilities to scorecard points*/
%macro transform_prob_to_scorecard(
/*********************************************************************************/
/*Input*/
input_pred_prob_dataset, /*Input dataset that has the estimated 
probability.*/
probability_variable, /*Variable that has the probabilities for the outcome*/
odds, /*Specifies the Non-Event/Event odds that correspond to the score value that you 
specify in the Scorecard Points property.*/
scorecard_points, /*Specifies a score that is associated with the odds that are specified in 
the Odds property. For example, if you use the default values of 200 and 50 for the Odds, a score of 
200 represents odds of 50 to 1 (that is P(Non-Event)/P(Event)=50).*/
point_double_odds, /*Increase in score points that generates the score that corresponds to 
twice the odds.*/
reverse_scorecard, /*Specifies whether the generated scorecard points should be reversed. 
Set to 0 if the higher the event rate the higher the score, and set to 1 if the higher the event rate 
the lower the score.*/
/*********************************************************************************/
/*Output*/
output_score_dataset /*Output dataset that has the computated scorecard value. The name of the new field is "scorecard".*/
);

data &output_score_dataset. (drop= factor offset);
format scorecard 8.2;
	set &input_pred_prob_dataset;
	factor = &point_double_odds. / log(2);
	offset = &scorecard_points. - factor*log(&odds.);
	if &reverse_scorecard=0 then scorecard = offset + factor*log(&probability_variable./(1-&probability_variable.));
	else if &reverse_scorecard=1 then scorecard = offset + factor*log((1-&probability_variable.)/&probability_variable.);
run;

%mend transform_prob_to_scorecard;
