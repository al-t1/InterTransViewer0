> **Note:** This repository is archived. It contains the original version of InterTransViewer described in Tyapkin et al. (2023) and is kept for reproducibility. **The new version is available as an R package at https://github.com/al-t1/InterTransViewer.**

# InterTransViewer0

## Description

ITV allows users to access and compare various characteristics of differential expression profiles derived from several different studies. In this case, a differential expression profile is a set of expression fold change values and the statistical significance of such a change between two experimental conditions for each gene (for example, between a group of samples treated with a phytohormone and an untreated control group).
Analyzed parameters include the number and the list of differentially expressed genes (DEGs) per study; for each gene, the number of studies in which it is differentially expressed; the number and the list of genes that are differentially expressed in at least one study (“joint DEGs”); the ratio of study-specific DEGs in each study; and the ratio between two values: the ratio of study-specific DEGs among the DEGs in the study and the ratio of the DEGs in this study among the joint DEGs. ITV also allows users to carry out pairwise comparisons of DEG content between all studies using several similarity metrics, hierarchical clustering of differential expression profiles, and homogeneity analysis using a bootstrap procedure.

## Essential requirements

- R v.4.1.2 or higher
- RStudio
- Windows OS

ITV checks the availability of the required packages and, if they are not found, automatically installs them using the `inst.load` function. The required packages are: 'tidyverse', 'tools', 'data.table', 'pheatmap', 'ggpubr', 'reshape2', 'dendextend', 'shipunov', 'RColorBrewer', 'svMisc'.

After the packages have been successfully installed, load all the functions (the first half of the script, up to the line «Start here»).
Unpack the archive containing example data into the folder where the script is located. Example data include 23 differential gene expression profiles induced by auxin treatment of *Arabidopsis thaliana* under different conditions (logFC and FDR values for each gene in every study) and 16 differential gene expression profiles induced by ethylene treatment of *A. thaliana*.

To use the example script on your own data, you need to supply a table with differential expression profiles named «condition_Profiles.csv», where «condition» is a user-defined name of the factor/treatment/condition being studied. Accordingly, you need to set the `condition` variable in the script to this name to load your data and create output files with correct names. Additionally, a table «condition_Description.csv» can also be supplied to provide more user-friendly names for your differential expression profiles and generated results (such as clustering and heatmaps). This table should contain rows with study metadata for each profile (for example: ID of a study, type of treatment, concentration of treatment, duration of treatment), and the rows must be in the same order as the profiles in your «condition_Profiles.csv» table. If this Description table is not needed, you can skip Description table processing in the script and use numerical identifiers matching the order of your profiles.

## Copyright

© 2023 Federal Research Center Institute of Cytology and Genetics,\
Siberian Branch of the Russian Academy of Sciences (ICG SB RAS).\
All rights reserved.

Authors: A.V. Tyapkin, A.D. Sidorenko, E.V. Zemlyanskaya.\
Registered computer program, Rospatent certificate No. 2023681227 (11.10.2023).

## Citation

If you use this code or its results, please cite:\
Tyapkin A.V., Lavrekha V.V., Ubogoeva E.V., Oshchepkov D.Yu., Omelyanchuk N.A.,\
Zemlyanskaya E.V. InterTransViewer: a comparative description of differential\
gene expression profiles from different experiments. Vavilov Journal of Genetics\
and Breeding. 2023;27(8):1042-1052. DOI 10.18699/VJGB-23-119
