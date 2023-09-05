# InterTransViewer0
Description:

ITV allows to access and compare various characteristics of differential expression profiles derived from several different studies. In this case, differential expression profile is a set of expression fold change values and the statistical significance of such change between two experimental conditions for each gene (for example, between group of samples treated with phytohormone and untreated control group).
Analyzed parameters include the number and the list of differentially expressed genes per study, the number of studies in which a gene is differentially expressed per each gene, the number and the list of genes which are differentially expressed in at least one study (“joint DEGs”); ratio of specific DEGS in each study; ratio between two values: ratio of specific DEGs among the DEGs in the study and ratio of the DEGs in this study among joint DEGs. ITV allows to carry out pairwise comparisons of DEG content between all studies using several similarity metrics; hierarchical clustering of differential expression profiles and homogeneity analysis using bootstrap procedure. 

Essential requirements:
•	R v.4.1.2 or higher
•	RStudio
•	Windows OS

It is highly advisable to use RStudio to ensure the correct loading and saving of data. It’s also advisable to run the script line by line (default keybind is Ctrl+Enter).
ITV checks the availability of the required packages and automatically installs them if not found using inst.load function. The required packages are:'tidyverse', 'tools', 'data.table', 'pheatmap', 'ggpubr', 'reshape2', 'dendextend', 'shipunov', 'RColorBrewer', 'svMisc'. 

After the packages have been successfully installed, load all the functions (the first half of the script until the line «Start here»). 
Unpack the archive containing example data into the folder where the script is located. Example data include 23 differential gene expression profiles induced by auxin treatment of Arabidopsis thaliana in different conditions (logFC and FDR values per each gene for every study) and 16 differential gene expression profiles induced by ethylene treatment of A. thaliana. 

To use the example script on your own data you need to supply the table with differential expression profiles with the name «condition_Profiles.csv», where «condition» is used-defined name of the factor/treatment/condition being studied. Accordingly, you need to replace the variable «condition» in the script to load your data and create output files with correct names. Additionally, a table «condition_Description.csv» could be supplied as well to provide more user-friendly names for your differential expression profiles and generated results (such as clustering and heatmaps). This table should contain rows with study metadata for each profile (for example: ID of a study, type of treatment, concentration of treatment, duration of treatment) and rows must in the same order as the profiles in your «condition_Profiles.csv» table. If this Description table is not necessary, you can skip Description table processing in the script and use numerical identifiers matching the order of your profiles.  
