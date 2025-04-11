# Scorecard Suite using SAS
This repository contains implementations of supervised machine learning solutions for various tasks. The codes are fully automated to perform data cleansing, data transformation, dimensionality reduction, model development, and reports generation. A summary of the automated process can be found in the [Scorecard Process Flow](tools/overview/Scorecard_Process_flow.pdf).
 
* **Data transformation** steps include: one hot encoding, impute missing values, data standardization, automated Weight of Evidence (WOE).
* **Dimensionality reduction** steps include: remove variables with high missing values percentage, remove character variables with many levels, drop numeric variables with only one value, drop variables based on low Gini, remove highly correlated features, remove features based on p-value information. 
* **Reports** include: data quality report, tables and graphs to assess the quality of the models. 

## Key Contents

* **src/process:** Codes that automate the scorecard development.

## Purpose

This repository serves as a collection of practical implementations and examples demonstrating different approaches to machine learning problems. It can be used for:

* **Learning and understanding:** Providing clear and concise code examples for developing scorecards.
* **Experimentation:** Offering a platform to test and compare different algorithms on various datasets.
* **Reference:** Serving as a quick reference for implementing common machine learning tasks.

## Structure

The repository is organized into logical directories to facilitate easy navigation and understanding of the codebase. More specifically:

* 'data' folder that includes subfolders related to data that are used as input to the solution, and data that are the output of the solution. 
* 'graphs' folder that includes graphs output. 
* 'logs' folder that includes logs output. 
* 'src' folder that includes macros ('macros') and summarized codes to execute the solution ('process').

## Contributions

Contributions, including bug fixes, new implementations, and improvements to existing code, are welcome! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines.

## License

Your use of the SAS_Scorecard_Suite repository is governed by the terms and conditions outlined in the [LICENSE.md](LICENSE.md) file of this repository. By proceeding, you acknowledge and agree to these terms.

**Keywords:** machine learning, supervised learning, classification, dimensionality reduction, SAS.