/*********************************************************************************/
/*Macro that calculates the Information values and the WOE information for a set list of variables*/
%macro ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list, /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list, /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable, /*Name of the target variable*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups, /*Number of binning groups for the numeric variables*/
adj_fact, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds, /*Dataset with all the information values*/
woe_format_outds, /*Dataset with the Weight of Evidence variables*/
output_formatted_data /*Original dataset, but with WOE variables instead of the original variables*/
);

%let varlist = &numeric_variables_list. &character_variables_list.;

%if &varlist. ne %then %do;

data input_dset;
      set &input_dset (keep= &target_variable. &varlist. &weight_variable.);
run;

proc sql noprint;
      select sum(&weight_variable.), sum(&target_variable.*&weight_variable.), sum(&weight_variable.)-sum(&target_variable.*&weight_variable.)
	into:total_all, :total_bads, :total_goods
      from input_dset
      ;
quit;

data &inf_val_outds.;
format variable $32. iv 8.2;
run;
data &woe_format_outds.;
format original_name fmtname $32. HLO SEXCL EEXCL $1. LABEL $50. bads all goods bads_pct all_pct goods_pct 8.2 end start $500. type $1.;
run;

%local varnum_num;
%local currvar_num;

%if &numeric_variables_list ne  %then %do;

%let varnum_num = %sysfunc(countw(&numeric_variables_list));

%do i = 1 %to &varnum_num;

      %let currvar_num = %scan(&numeric_variables_list,&i);
      %put &currvar_num;

%let by_univariate = %sysfunc(round(100/&groups., 0.0000001));
proc univariate data=input_dset noprint;
	var &currvar_num.;
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
%if %substr(&currvar_num., %length(&currvar_num.), 1)=0 or 
%substr(&currvar_num., %length(&currvar_num.), 1)=1 or
%substr(&currvar_num., %length(&currvar_num.), 1)=2 or
%substr(&currvar_num., %length(&currvar_num.), 1)=3 or 
%substr(&currvar_num., %length(&currvar_num.), 1)=4 or 
%substr(&currvar_num., %length(&currvar_num.), 1)=5 or 
%substr(&currvar_num., %length(&currvar_num.), 1)=6 or 
%substr(&currvar_num., %length(&currvar_num.), 1)=7 or 
%substr(&currvar_num., %length(&currvar_num.), 1)=8 or 
%substr(&currvar_num., %length(&currvar_num.), 1)=9 %then %do;
	%let var_length = %eval(%length(&currvar_num.));
	%let proposed_name=%sysfunc(cats(%substr(&currvar_num., 1, &var_length.),z));
%end;
%else %do;
	%let proposed_name=&currvar_num.;
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
	set input_dset (keep= &target_variable. &currvar_num. &weight_variable.);
/*	value = input(put(&currvar_num., $score.), 8.);*/
	value = put(&currvar_num., &proposed_name..);
run;

/*      proc means data=rank1 median mean min max nway noprint;*/
/*            class value;*/
/*            var &currvar_num;*/
/*            output out=rank1_means(drop=_type_ _freq_)*/
/*            median=med_origv*/
/*            mean=mean_origv*/
/*            min=min_origv*/
/*            max=max_origv;*/
/*      run;*/
      

      proc sql;
            create table rank2
            as select
                  "&currvar_num." as variable format $32.
            , value
            ,sum(&target_variable.*&weight_variable.) as bads
            ,sum(&weight_variable.) as all
            ,calculated all - calculated bads as goods
            ,sum(calculated bads,&adj_fact) / sum(&total_bads,&adj_fact) as bads_pct
            ,sum(calculated all,&adj_fact) / sum(&total_all,&adj_fact) as all_pct
            ,sum(calculated goods,&adj_fact) / sum(&total_goods.,&adj_fact) as goods_pct
            ,log(calculated goods_pct / calculated bads_pct) as woe
            from rank1
            group by value
            ;
      quit;
/*        proc sql;*/
/*        create table rank2 as */
/*        select */
/*            t1.**/
/*            , t2.med_origv*/
/*            , t2.mean_origv*/
/*            , t2.min_origv*/
/*            , t2.max_origv*/
/*        from rank2 as t1*/
/*        left join rank1_means as t2*/
/*        on t1.value = t2.value*/
/*        ;*/
/*        quit;*/

        proc sql;
        create table rank4 as 
        select 
            t1.*
            , t2.*
        from cntlin (rename=(label=label_old)) as t1
        left join rank2 (drop=variable) as t2
        on t1.label_old = t2.value
        ;
        quit;

		data rank4;
		format start end $80.;
			set rank4 (rename=(end=end_old start=start_old /*fmtname=original_name*/));
			label = strip(put(woe, 13.10));
			end = strip(put(end_old, 32.10));
			start = strip(put(start_old, 32.10));
			original_name = "&currvar_num.";
/*			if substr(original_name, length(original_name), 1) in ('0','1','2','3','4','5','6','7','8','9') then fmtname=cats(original_name,'z');*/
/*			else fmtname = original_name;*/
		run;

      data rank3;
            attrib variable length = $32;
            retain variable;
            variable = "&currvar_num";
            set rank2 end = last;
            retain iv 0;
            iv + (woe * sum(-1*bads_pct,goods_pct));
            if last;
      run;
      
            proc append base = &inf_val_outds. data = rank3(keep = variable iv) force;
            run;
            proc append base = &woe_format_outds. data = rank4 force;
            run;

%end;

%end;

%local varnum_char;
%local currvar_char;


%if &character_variables_list ne  %then %do;

%let varnum_char = %sysfunc(countw(&character_variables_list));
%put &varnum_char;

%do i = 1 %to &varnum_char;

      %let currvar_char = %scan(&character_variables_list,&i);
      %put &currvar_char;

data rank1;
	set input_dset (keep= &target_variable. &currvar_char. &weight_variable. rename=(&currvar_char.=value));
run;

      proc sql;
            create table rank2
            as select
                  "&currvar_char." as variable format $32.
            , value
            ,sum(&target_variable.*&weight_variable.) as bads
            ,sum(&weight_variable.) as all
            ,calculated all - calculated bads as goods
            ,sum(calculated bads,&adj_fact) / sum(&total_bads,&adj_fact) as bads_pct
            ,sum(calculated all,&adj_fact) / sum(&total_all,&adj_fact) as all_pct
            ,sum(calculated goods,&adj_fact) / sum(&total_goods.,&adj_fact) as goods_pct
            ,log(calculated goods_pct / calculated bads_pct) as woe
			, 'C' as type
            from rank1
            group by value
            ;
      quit;

	data rank2;
	  	set rank2 (rename=(variable=original_name));
			label = strip(put(woe, 13.10));
			if substr(original_name, length(original_name), 1) in ('0','1','2','3','4','5','6','7','8','9') then fmtname=cats(original_name,'p');
			else fmtname = original_name;
			start = value;
			end = value;
	run;

      data rank3;
            attrib variable length = $32;
            retain variable;
            variable = "&currvar_char";
            set rank2 end = last;
            retain iv 0;
            iv + (woe * sum(-1*bads_pct,goods_pct));
            if last;
      run;
      
            proc append base = &inf_val_outds. data = rank3(keep = variable iv) force;
            run;
            proc append base = &woe_format_outds. data = rank2 force;
            run;

%end;

%end;

data &woe_format_outds.;
	set &woe_format_outds.;
	where not(missing(fmtname));
run;
data &inf_val_outds.;
	set &inf_val_outds.;
	where not(missing(variable));
run;

proc sort data=&inf_val_outds.;
      by descending iv variable;
run;
run;

proc format cntlin = &woe_format_outds.; 
run;

proc sql noprint;
select distinct fmtname, original_name 
	into :format_name separated by ' ', :variables_original_name separated by ' '
from &woe_format_outds.
;
quit;

/*Recode the original character variables dataset based on the new formats*/
%local varnum;
%let varnum = %sysfunc(countw(&variables_original_name.));
%put Total number of variables to recode: &varnum.;
%local curr_var curr_format;
data &output_formatted_data.
(
drop=
	%do i = 1 %to &varnum.;
		%let curr_var = %scan(&variables_original_name., &i.);
		%let var_length = %eval(%length(&curr_var.));
		%let proposed_name = %sysfunc(cats(%substr(&curr_var., 1, &var_length.),z));
		&proposed_name.
	%end;
)
;
	set &input_dset.
(
rename=
(
	%do i = 1 %to &varnum.;
		%let curr_var = %scan(&variables_original_name., &i.);
		%let var_length = %eval(%length(&curr_var.));
		%let proposed_name = %sysfunc(cats(%substr(&curr_var., 1, &var_length.),z));
		&curr_var. = &proposed_name.
	%end;
)
)
;
	%do i = 1 %to &varnum.;
		%let curr_var = %scan(&variables_original_name., &i.);
		%let var_length = %eval(%length(&curr_var.));
		%let proposed_name = %sysfunc(cats(%substr(&curr_var., 1, &var_length.),z));
		%let curr_format = %scan(&format_name., &i);
		%put Iteration &i., variable &curr_var., format &curr_format.;
		&curr_var. = input(put(&proposed_name.,&curr_format..), 8.5);
	%end;
run;

%end;

%mend ivs_and_woe_table;
/*********************************************************************************/

