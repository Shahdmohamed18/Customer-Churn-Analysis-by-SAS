
/*load data*/
FILENAME REFFILE '/home/u64501493/customer_churn.csv.xls';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=work.customer_churn
	REPLACE;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=work.customer_churn; RUN;


%web_open_table(work.customer_churn);

/* rename cols */
data work.customer_churn;
    set work.customer_churn;

    rename
        'Subscription Type'n = Subscription
        'Contract Length'n = ContractLength
        'Usage Frequency'n = UsageFrequency
        'Support Calls'n = SupportCalls
        'Payment Delay'n = PaymentDelay
        'Total Spend'n = TotalSpend
        'Last Interaction'n = LastInteraction;
run;


/*============== Step 1: Inspect Dataset Structure ==============*/
PROC CONTENTS data=work.customer_churn;
RUN;

/*============== Step 2: View First 20 Observations ==============*/
PROC PRINT data=work.customer_churn (obs=20);
RUN;

/*============== Step 3: Check Data Quality ==============*/
PROC MEANS data=work.customer_churn n nmiss min max;
RUN;

/*============== Step 4: Check Duplicates ==============*/
PROC FREQ data=work.customer_churn noprint;
    tables CustomerID / out=id_counts;
RUN;

PROC PRINT data=id_counts;
    where COUNT > 1;
RUN;
/* there are no duplicates */

/*============== Step 5: Outlier Detection (Z-score) ==============*/

/* Step 5.1: Standardize numeric variables */
PROC STANDARD data=work.customer_churn mean=0 std=1 out=std_data;
    var _numeric_;
RUN;

/* Step 5.2: Flag extreme values */
DATA outliers_all;
    set std_data;
    array vars _numeric_;
    outlier_flag = 0;
    do i = 1 to dim(vars);
        if abs(vars{i}) > 3 then outlier_flag + 1;
    end;
    drop i;
RUN;

/* Step 5.3: View outlier rows */
PROC PRINT data=outliers_all;
    where outlier_flag > 0;
RUN;

/*============== Step 6: Target Variable Distribution ==============*/
PROC FREQ data=work.customer_churn;
    tables Churn;
RUN;

/*============== Step 7: Categorical Variables vs Churn ==============*/

/* Gender vs Churn */
PROC FREQ data=work.customer_churn;
    tables Gender*Churn;
RUN;

/* Subscription vs Churn */
PROC FREQ data=work.customer_churn;
    tables Subscription*Churn;
RUN;

/* ContractLength vs Churn */
PROC FREQ data=work.customer_churn;
    tables ContractLength*Churn;
RUN;

/*============== Step 8: Numerical Variables vs Churn ==============*/
PROC MEANS data=work.customer_churn mean min max;
    class Churn;
    var Tenure UsageFrequency SupportCalls PaymentDelay TotalSpend Age;
RUN;

/* Hypothesis 1: Shorter tenure = higher churn */
PROC MEANS data=work.customer_churn;
    class Churn;
    var Tenure;
RUN;

/* Hypothesis 2: More support calls = higher churn */
PROC MEANS data=work.customer_churn;
    class Churn;
    var SupportCalls;
RUN;

/* Hypothesis 3: Lower usage frequency = higher churn */
PROC MEANS data=work.customer_churn;
    class Churn;
    var UsageFrequency;
RUN;

/*============== Step 9: Visualizations (Before Cleaning) ==============*/

/* Tenure Distribution */
title 'Tenure Distribution - Before Cleaning';
PROC SGPLOT data=work.customer_churn;
    histogram Tenure;
RUN;
title;

/* Churn Rate by Subscription Type */
title 'Churn Rate by Subscription Type - Before Cleaning';
PROC SGPLOT data=work.customer_churn;
    vbar Subscription / group=Churn stat=percent groupdisplay=cluster;
RUN;
title;

/* Churn Rate by Contract Length */
title 'Churn Rate by Contract Length - Before Cleaning';
PROC SGPLOT data=work.customer_churn;
    vbar ContractLength / group=Churn stat=percent groupdisplay=cluster;
RUN;
title;

/* Tenure vs Churn - Boxplot */
title 'Tenure vs Churn - Before Cleaning';
PROC SGPLOT data=work.customer_churn;
    vbox Tenure / category=Churn;
RUN;
title;

/* UsageFrequency vs Churn - Boxplot */
title 'UsageFrequency vs Churn - Before Cleaning';
PROC SGPLOT data=work.customer_churn;
    vbox UsageFrequency / category=Churn;
RUN;
title;

/* SupportCalls vs Churn - Boxplot */
title 'SupportCalls vs Churn - Before Cleaning';
PROC SGPLOT data=work.customer_churn;
    vbox SupportCalls / category=Churn;
RUN;
title;

/* UsageFrequency vs TotalSpend - Scatter */
title 'UsageFrequency vs TotalSpend - Before Cleaning';
PROC SGPLOT data=work.customer_churn;
    scatter x=UsageFrequency y=TotalSpend / group=Churn;
RUN;
title;

/* Correlation Matrix */
PROC CORR data=work.customer_churn plots=matrix;
    var Age Tenure UsageFrequency SupportCalls PaymentDelay TotalSpend;
RUN;

/* Tenure Groups vs Churn */
DATA churn_groups;
    set work.customer_churn;
    if Tenure < 12      then TenureGroup = '0-12';
    else if Tenure < 24 then TenureGroup = '12-24';
    else                     TenureGroup = '24+';
RUN;

title 'Churn Rate by Tenure Group - Before Cleaning';
PROC SGPLOT data=churn_groups;
    vbar TenureGroup / group=Churn stat=percent groupdisplay=stack;
RUN;
title;

/*====================== Preprocessing ===================*/

/*============== Step 1: Create Clean Table & Fix Issues ===========*/
DATA work.customer_clean;
    set work.customer_churn;
    
    /*==== Fix Gender Typos ====*/
    if Gender in ('Femal', 'FEMAL') then Gender = 'Female';
    if Gender in ('MLE', 'Mle')     then Gender = 'Male';
    
    /*==== Fix Subscription Typos ====*/
    if Subscription in ('Bsc', 'bsc')       then Subscription = 'Basic';
    if Subscription in ('Prmium', 'prmium') then Subscription = 'Premium';
    if Subscription in ('Stndrd', 'stndrd') then Subscription = 'Standard';
        
    /*==== Fix Outliers ====*/
    if Age > 100            then Age = .;
    if Tenure > 60          then Tenure = .;
    if UsageFrequency > 30  then UsageFrequency = .;
RUN;


 
/*============== Step 2: Handle Missing Values ===========
Data has only 61 missing value (only 3%), so deleting rows with missing values won't make a problem */
DATA work.customer_clean;
    set work.customer_clean;

    if cmiss(of _all_) = 0;
RUN;

/*============== Step 3: Verify Cleaning Results ===========*/
PROC MEANS data=work.customer_clean n nmiss min max;
RUN;

/*============== Step 4: Visualizations After Cleaning ===========*/

/* Tenure vs Churn */
title 'Tenure vs Churn - After Cleaning';
PROC SGPLOT data=work.customer_clean;
    vbox Tenure / category=Churn;
RUN;
title;

/* UsageFrequency vs Churn */
title 'UsageFrequency vs Churn - After Cleaning';
PROC SGPLOT data=work.customer_clean;
    vbox UsageFrequency / category=Churn;
RUN;
title;

/* Churn Rate by Subscription Type */
title 'Churn Rate by Subscription Type - After Cleaning';
PROC SGPLOT data=work.customer_clean;
    vbar Subscription / group=Churn stat=percent groupdisplay=cluster;
RUN;
title;

/* Churn Rate by Gender */
title 'Churn Rate by Gender - After Cleaning';
PROC SGPLOT data=work.customer_clean;
    vbar Gender / group=Churn stat=percent groupdisplay=cluster;
RUN;
title;

 
/*====================== FEATURE ENGINEERING ===================*/
DATA work.customer_fe;
    set work.customer_clean;


/*FEATURE 1: SupportCallsPerMonth
Why: Normalizes support calls by tenure to remove bias.
High calls relative to tenure = frustrated customer.
*/

    if Tenure > 0 then SupportCallsPerMonth = SupportCalls / Tenure;
    else SupportCallsPerMonth = SupportCalls;

 /*FEATURE 2: SpendPerMonth
Why: Average monthly spend = customer perceived value.
Low spend per month → higher churn risk.
*/
    if Tenure > 0 then SpendPerMonth = TotalSpend / Tenure;
    else SpendPerMonth = TotalSpend;

/*FEATURE 3: HighRiskScore
Why: Composite binary flag of 3 churn signals combined:
High support calls + Low usage + High payment delay.*/
    if SupportCalls >= 5 and UsageFrequency <= 5 and PaymentDelay >= 15
        then HighRiskScore = 1;
    else HighRiskScore = 0;

/*FEATURE 4: TenureGroup_Num
Why: Captures non-linear relationship between tenure & churn.
1 = New (0-12m)  → highest risk
2 = Mid (12-24m) → medium risk
3 = Loyal (24+m) → lowest risk
*/
    if Tenure < 12      then TenureGroup_Num = 1;
    else if Tenure < 24 then TenureGroup_Num = 2;
    else                     TenureGroup_Num = 3;

/*FEATURE 5: Dummy Variables
Why: PROC LOGISTIC needs numeric inputs for categoricals.
*/

/* Gender */
    if Gender = 'Female' then Gender_Female = 1;
    else Gender_Female = 0;

/* Subscription (reference = Basic) */
    if Subscription = 'Premium'  then Sub_Premium  = 1; else Sub_Premium  = 0;
    if Subscription = 'Standard' then Sub_Standard = 1; else Sub_Standard = 0;

/* Contract Length (reference = Annual) */
    if ContractLength = 'Monthly'   then Contract_Monthly   = 1; else Contract_Monthly   = 0;
    if ContractLength = 'Quarterly' then Contract_Quarterly = 1; else Contract_Quarterly = 0;

RUN;

/* Verify new features */
title 'Summary of Engineered Features';
PROC MEANS data=work.customer_fe n mean min max;
    var SupportCallsPerMonth SpendPerMonth HighRiskScore
        TenureGroup_Num Gender_Female Sub_Premium Sub_Standard
        Contract_Monthly Contract_Quarterly;
RUN;
title;

/* Visualize new features vs Churn */

title 'High Risk Score vs Churn Rate';
PROC SGPLOT data=work.customer_fe;
    vbar HighRiskScore / group=Churn stat=percent groupdisplay=cluster;
RUN;
title;

title 'Support Calls Per Month vs Churn';
PROC SGPLOT data=work.customer_fe;
    vbox SupportCallsPerMonth / category=Churn;
RUN;
title;

title 'Spend Per Month vs Churn';
PROC SGPLOT data=work.customer_fe;
    vbox SpendPerMonth / category=Churn;
RUN;
title;

title 'Tenure Group vs Churn Rate';
PROC SGPLOT data=work.customer_fe;
    vbar TenureGroup_Num / group=Churn stat=percent groupdisplay=cluster;
RUN;
title;

/* Correlation: engineered features vs Churn */
title 'Correlation of Engineered Features with Churn';
PROC CORR data=work.customer_fe;
    var SupportCallsPerMonth SpendPerMonth HighRiskScore
        TenureGroup_Num PaymentDelay UsageFrequency;
    with Churn;
RUN;

/*Logistic Regression model*/
title;
PROC SURVEYSELECT data=work.customer_fe out=work.customer_split 
    seed=12345 method=srs samprate=0.7 outall;
RUN;

DATA work.train work.test;
    set work.customer_split;
    if selected = 1 then output work.train;
    else output work.test;
RUN;
title 'Logistic Regression Model for Customer Churn';
PROC LOGISTIC data=work.train descending;
 
    model Churn = Age Tenure UsageFrequency SupportCalls PaymentDelay 
                  SupportCallsPerMonth SpendPerMonth HighRiskScore 
                  TenureGroup_Num Gender_Female Sub_Premium 
                  Sub_Standard Contract_Monthly Contract_Quarterly 
          / selection=stepwise
            details lakfit;
    
    
    score data=work.test out=work.predictions; 
RUN;
title;

DATA work.eval;
    set work.predictions;
    
    if P_1 > 0.5 then predicted_churn = 1;
    else predicted_churn = 0;
RUN;

/* Confusion Matrix */
title 'Model Performance: Confusion Matrix';
PROC FREQ data=work.eval;
    tables Churn*predicted_churn / nocol nopercent;
RUN;
title;







