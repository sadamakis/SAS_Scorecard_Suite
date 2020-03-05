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
/* Program Name:             ---  transform_prob_to_scorecard.sas										*/
/* Description:              ---  Transform probabilities to scorecard points							*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
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
eps, /*Adjustment factor to provide a score even when a probability is 0 or 1*/
/*********************************************************************************/
/*Output*/
output_score_dataset /*Output dataset that has the computated scorecard value. The name of the new field is "scorecard".*/
);

data &output_score_dataset. (drop= factor offset);
format scorecard 8.2;
	set &input_pred_prob_dataset;
	factor = &point_double_odds. / log(2);
	offset = &scorecard_points. - factor*log(&odds.);
	if &reverse_scorecard=0 then scorecard = offset + factor*log((&probability_variable.+&eps.)/(1-&probability_variable.+&eps.));
	else if &reverse_scorecard=1 then scorecard = offset + factor*log((1-&probability_variable.+&eps.)/(&probability_variable.+&eps.));
run;

%mend transform_prob_to_scorecard;
