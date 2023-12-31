#InterTransViewer

### Clear your environment if needed
rm(list = ls(all.names = TRUE))
### Or use Ctrl+Shift+F10 to reset RStudio.

#Set the current directory as a working directory.
#Alternatively, use other means like 'here' R package.
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
cat('Current directory: ',dirname(rstudioapi::getActiveDocumentContext()$path))
dir.create('Results',showWarnings=F)

#Load required packages and install them automatically if needed.
packages <- c("tidyverse", 'tools','data.table','pheatmap','ggpubr',
              'reshape2','dendextend','shipunov','RColorBrewer','svMisc')
inst.load <- function(package){
  new_package <- package[!(package %in% installed.packages()[, "Package"])]
  if (length(new_package))
    install.packages(new_package, dependencies = TRUE)
  sapply(package, require, character.only = TRUE)
}
inst.load(packages)

#_______________________________________________________
#Load functions.

#Parsing function for merging the results generated by limma topTable function 
#or DESeq2 results function for microarray and RNA-seq data.
DE_weave <- function(input_type = NULL, capitalize = T, columns_to_use = NULL){
  files <- list.files('Experiments')
  df_list <- list()
  for (file in files){
    df <- fread(paste0('Experiments/',file),data.table=F)
    cols <- colnames(df)
    file_types = 0
    if (file_types == 'ID_logFC_FDR'){
      df1 <- df %>% select(1,2,3)
      colnames(df1) <- c('ID',paste0(file_path_sans_ext(file),'.logFC'),paste0(file_path_sans_ext(file),'.FDR'))
      if (capitalize == T){
        df1$ID <- toupper(df1$ID)
      }
      df_list[[file]] <- df1
      
    } else if ((file_types == 'DESeq2')|(('log2FoldChange' %in% cols)&('padj' %in% cols))){
      print(paste0('File: ',file,' ... Type: DESeq2 output.'))
      df1 <- df %>% select(1,'log2FoldChange','padj')
      colnames(df1) <- c('ID',paste0(file_path_sans_ext(file),'.logFC'),paste0(file_path_sans_ext(file),'.FDR'))
      if (capitalize == T){
        df1$ID <- toupper(df1$ID)
      }
      df_list[[file]] <- df1
    } else if ((file_types == 'limma')|(('Symbol.AGI' %in% cols)&('logFC' %in% cols)&('adj.P.Val' %in% cols))){
      print(paste0('File: ',file,' ... Type: limma output.'))
      if (cols[2] != 'logFC'){
        df1 <- df %>% select(2,'logFC','adj.P.Val')
        colnames(df1) <- c('ID',paste0(file_path_sans_ext(file),'.logFC'),paste0(file_path_sans_ext(file),'.FDR'))
        if (capitalize == T){
          df1$ID <- toupper(df1$ID)
        }
        df_list[[file]] <- df1
      } else {
        df1 <- df %>% select(1,'logFC','adj.P.Val')
        colnames(df1) <- c('ID',paste0(file_path_sans_ext(file),'.logFC'),paste0(file_path_sans_ext(file),'.FDR'))
        if (capitalize == T){
          df1$ID <- toupper(df1$ID)
        }
        df_list[[file]] <- df1
      }
    } else if (!is.null(columns_to_use)){
      print(paste0('File: ',file,' ... User-defined order.'))
      print(paste0('ID:',columns_to_use[1],'logFC:',columns_to_use[2],'FDR:',columns_to_use[3],))
      if (length(columns_to_use) == 3){
        df1 <- df %>% select(columns_to_use[1],columns_to_use[2],columns_to_use[3])
        colnames(df1) <- c('ID',paste0(file_path_sans_ext(file),'.logFC'),paste0(file_path_sans_ext(file),'.FDR'))
        if (capitalize == T){
          df1$ID <- toupper(df1$ID)
        }
        df_list[[file]] <- df1
      } else {
        print('Define columns using vector of three numbers.')
        print('First: index of the column containing gene IDs,')
        print('Second: index of logFC column, third: index of FDR column.')
        print('For example, DE_weave(columns_to_use = c(1,2,3))')
      }
    } else {
      print('Unknown format, using first three columns.')
      df1 <- df %>% select(1,2,3)
      colnames(df1) <- c('ID',paste0(file_path_sans_ext(file),'.logFC'),paste0(file_path_sans_ext(file),'.FDR'))
      if (capitalize == T){
        df1$ID <- toupper(df1$ID)
      }
      df_list[[file]] <- df1
      }
  } 
  if (length(df_list) == 1){
    return (df_list[1])
  } else if (length(df_list) > 1){
    df_merged <- df_list %>% reduce(full_join, by='ID')
    return (df_merged)
  } else {
    return (NA)
  }
}

#Function rearranges the initial table to keep only significant logFC values.
#If needed, change logFC_cutoff, for example, to logFC_cutoff=log2(1.5)
#so only genes with FC lower than -1.5 and higher than 1.5 will be kept
SignifTable <- function(profiles,FDR_cutoff, logFC_cutoff = 0){
  if(any(duplicated(profiles[,1]))){
    warning ('Duplicated IDs found, keeping the first duplicated value.')
    profiles <- profiles[!duplicated(profiles[,1]),]
  }
  fc_col <- seq(2,ncol(profiles), 2)
  p_vals <- seq(3,ncol(profiles), 2)
  sgnf_profiles <- profiles
  sgnf_profiles[is.na(sgnf_profiles)] <- 1
  for (i in p_vals){
    sgnf_profiles[(abs(sgnf_profiles[,i-1])<logFC_cutoff) | (sgnf_profiles[,i]>=FDR_cutoff), c(i-1,i)] = NA
  }
  sgnf_profiles <- merge(sgnf_profiles[,c(1,fc_col)],sgnf_profiles[,c(1,p_vals)],by=colnames(sgnf_profiles)[1])
  rownames(sgnf_profiles) <- sgnf_profiles[,1]
  sgnf_profiles <- sgnf_profiles[,-c(1)]
  fc_col_new <- c(1:round(ncol(sgnf_profiles)/2))
  pvals_new <- c((round(ncol(sgnf_profiles)/2)+1):ncol(sgnf_profiles))
  DEG_calls_per_gene <- apply(sgnf_profiles[,fc_col_new],
                              MARGIN = 1, FUN = function (x){sum(!is.na(x),na.rm = T)})
  sgnf_profiles <- sgnf_profiles[DEG_calls_per_gene > 0,]
  sgnf_profiles <- sgnf_profiles[,c(1:round(ncol(sgnf_profiles)/2))]
  return (sgnf_profiles)
}

#Get number of DEGs in each experiment.
DEGsPerExperiment <- function(sgnf_profiles){
  DEG_calls_per_exp <- apply(sgnf_profiles,MARGIN = 2, 
                             FUN = function (x){sum(!is.na(x),na.rm = T)})
  return(DEG_calls_per_exp)
}
#Get number of the experiments in which the gene is DEG.
ExperimentsPerDEG <- function(sgnf_profiles){
  DEG_calls_per_gene <- apply(sgnf_profiles, MARGIN = 1, 
                              FUN = function (x){sum(!is.na(x),na.rm = T)})
  return(DEG_calls_per_gene)
}

NeverDEG <- function(all_genes = rownames(Profiles[[condition]]),
                     jointDEGs = rownames(Signifs[[condition]])){
  neverDEGs <- setdiff(all_genes, jointDEGs)
  return(neverDEGs)
}
  


DE_clustering <- function(profiles, FDR_cutoff, threshold = 0, 
                          iter = 500,method = 'ward.D2',
                          change_names_to = NULL, insignif_to_zero = FALSE){
  rownames(profiles) <- profiles[,1]
  profiles <- na.omit(profiles)
  profiles[profiles == 'Inf'] = NA
  profiles <- na.omit(profiles)
  profiles <- profiles[,-c(1)]
  p_val_cols <- seq(2,ncol(profiles), 2)
  df_p <- profiles[, p_val_cols]
  sum_sign = apply(df_p,MAR=1,FUN=function(x){sum(x<FDR_cutoff,na.rm=T)})
  apriori_list=rownames(profiles[which(sum_sign >= threshold),])
  if (insignif_to_zero){
    for (j in p_val_cols){
      profiles[(profiles[,j]>=FDR_cutoff), c(j-1)] = 0
    }
  }
  fc_col <- seq(1,ncol(profiles), 2)
  df <- profiles[rownames(profiles)%in%apriori_list,fc_col]
  if (!(is.null(change_names_to))){
    colnames(df) <- change_names_to
  }
  SS=t(df)
  SS=t(apply(SS,MAR=1,FUN=function(x){(x)/(max(x)-min(x))}))
  SS=(apply(SS,MAR=2,FUN=function(x){(x)/(sd(x))}))
  DD=dist(SS)
  l=hclust(DD,method="ward.D2")
  dend <- as.dendrogram(l)
  dend_labels <- labels(dend)
  labels(dend) <- ""
  bb = Bclust(SS, method.c="ward.D2",iter=iter)
  return (list(dend,dend_labels,bb,df))
}

DE_summary <- function(melted_table){
  N_all <- length(unique(melted_table$ID))
  exps <- unique(melted_table$exp)
  totals_n <- c()
  specifics_n <- c()
  specific_DEGs <- melted_table[0,]
  for (exp in exps) {
    total <- melted_table[melted_table$exp == exp,]
    background <- melted_table[melted_table$exp != exp,]
    specific <- setdiff(total$ID,background$ID)
    specifics_n <- append(specifics_n,length(specific))
    totals_n <- append(totals_n,length(total$ID))
    if (length(specific)!=0){
      specific <- data.frame(ID = specific)
      specific <- merge(specific, total, by = 'ID')
      specific_DEGs <- rbind(specific_DEGs,specific)
    }
  }
  df_tsd <- data.frame(exps)
  df_tsd$total <- totals_n
  df_tsd$specific <- specifics_n
  df_tsd$specific_percent <- round((df_tsd$specific/df_tsd$total)*100,2)
  df_tsd$Rmetric <- (df_tsd$specific/df_tsd$total)/(df_tsd$total/N_all)
  return (list(df_tsd,specific_DEGs))
}

KeepExps <- function (sgnf_profiles,indexes = NULL, nDEG_lower_bound = 0, nDEG_upper_bound = Inf){
  if (!is.null(indexes)){
    sgnf_profiles <- sgnf_profiles[,indexes]
  }
  DEG_number <- DEGsPerExperiment(sgnf_profiles)
  if ((nDEG_lower_bound < max(DEG_number))&(nDEG_upper_bound > min(DEG_number))){
    DEG_names <- rownames(sgnf_profiles)
    exps_to_keep <- names(DEG_number[(DEG_number > nDEG_lower_bound)&(DEG_number < nDEG_upper_bound)])
    if (length(exps_to_keep)==1){
      sgnf_profiles <- data.frame(sgnf_profiles[,(names(sgnf_profiles) %in% exps_to_keep)])
      colnames(sgnf_profiles) <- exps_to_keep[1]
      rownames(sgnf_profiles) <- DEG_names
    }
    else
    {
      sgnf_profiles <- sgnf_profiles[,(names(sgnf_profiles) %in% exps_to_keep)]
    }
    return (sgnf_profiles)
  }
  else
  {
    warning (paste0('Lower bound cannot be higher than ',max(DEG_number),
                    ',\nupper bound cannot be lower than ',min(DEG_number)))
    print('Try again')
    return(sgnf_profiles)
  }
}

#Get lists of DEG IDs from melted data for comparisons.
GetDEGLists <- function(melted_table){
  DEG_lists = list()
  names = unique(melted_table[,'exp'])
  for (name in names){
    DEG_lists[[name]] = melted_table[melted_table[,'exp'] == name,][,'ID']
  }
  return (DEG_lists)
}

#Create similarity matrix for the heatmap plotting.
GetSimMatrix <- function(item_list, tags = names(item_list), metric = 'similarity') {
  NAs_to_kill <- c()
  item_matrix = matrix(nrow = length(item_list),ncol=length(item_list))
  if (metric == 'similarity'){
    print('Heatmap is based on the similarity metric I.')
    #Define similarity metric for the heatmap.
    sim_metric <- function(a, b) {
      Y = length(intersect(a, b))
      X = length(setdiff(a,b))
      Z = length(setdiff(b,a))
      A = min(X,Z)
      siM = Y/(A+Y)
      return (siM)
    }
    for (i in (1:length(item_list))){
      for (j in (1:length(item_list))){
        item_matrix[i,j] = sim_metric(unlist(item_list[i],use.names = F),unlist(item_list[j],use.names = F))
      }
      if (is.na(item_list[i])){
        NAs_to_kill <- append(NAs_to_kill,i)
      }
    }
  } else if (metric == 'jaccard') {
    print('Heatmap is based on the Jaccard metric')
    jaccard <- function(a, b) {
      intersection = length(intersect(a, b))
      union = (length(a) + length(b) - intersection)
      return (intersection/union)
    }
    for (i in (1:length(item_list))){
      for (j in (1:length(item_list))){
        item_matrix[i,j] = jaccard(unlist(item_list[i],use.names = F),unlist(item_list[j],use.names = F))
      }
      if (is.na(item_list[i])){
        NAs_to_kill <- append(NAs_to_kill,i)
      }
    }
  } else {
    print('Specify either similarity metric I or Jaccard metric')
  }
  rownames(item_matrix) <- tags
  colnames(item_matrix) <- tags
  for (NAs in NAs_to_kill) {
    item_matrix[NAs,] <- NA
    item_matrix[,NAs] <- NA
  }
  return(item_matrix)
}

PlotSimHeatmap <- function(item_matrix,clustering = TRUE,clustering_method = 'ward.D2'){
  if (clustering == TRUE){
    pm <- pheatmap(item_matrix, clustering_method = clustering_method)
  } else {
    pm <- pheatmap(item_matrix, cluster_rows = F, cluster_cols = F)
  }
  return (pm)
}

DE_bootstrap <- function(melted_table1,melted_table2=melted_table1,
                                  size1 = length(unique(melted_table1$exp)),
                                  sizes2 = c((length(unique(melted_table1$exp))-1):1),
                                  iters=100){
  c = 0
  cn = iters*length(sizes2)
  exps1u <- unique(melted_table1$exp)
  exps2u <- unique(melted_table2$exp)
  boots <- list()
  for (size2 in sizes2){
    boot <- c()
    for (iter in c(1:iters)){
      vector1 <- sample(exps1u,size = size1,replace=T)
      vector2 <- sample(exps2u,size = size2,replace=T)
      lengths1 <- c()
      lengths2 <- c()
      for (j in vector1){
        lengths1 <- append(lengths1,melted_table1[melted_table1$exp == j,]$ID)
      }
      for (j in vector2){
        lengths2 <- append(lengths2,melted_table2[melted_table2$exp == j,]$ID)
      }
      lengths1 <- length(unique(lengths1))
      lengths2 <- length(unique(lengths2))
      d = lengths1 - lengths2
      boot <- append(boot, d)
      c = c + 1
      progress(c,cn)
    }
    boots[[size2]] <- boot
  }
  return (boots)
}

PlotHistBootstrap <- function(BS_results,column_name, breaks = 50, hist_name=''){
  pdf(paste0('Results/',column_name,'_',nrow(BS_results),'iterations.pdf'),width = 10,height = 5)
  #par(mar=c(12, 5, 5, 3)+0.1)
  h <- hist(plot=FALSE, BS_results[,column_name],breaks=breaks)
  h$counts=h$counts/sum(h$counts)
  lq = quantile(BS_results[,column_name],0.025)
  rq = quantile(BS_results[,column_name],0.975)

  plot(h, border = '#279AF1', col = '#279AF9', xlim = range(min(BS_results),max(BS_results)),
      main = paste0(hist_name,'\n95-percentile confidence interval = [',lq,',',rq,']'),
      sub = paste0(nrow(BS_results),' iterations'),xlab=paste('d'))

  abline(v=lq,col='red',lty = 'dotted',lwd=1.5)
  abline(v=rq,col='red',lty = 'dotted',lwd=1.5)
  abline(v=0,col='red',lty = 'longdash',lwd=1.5)
  dev.off()
  return()
}

TotalSpecPlot <- function(TotalSpecRatio, width=8,height=6){
  dir.create('Results')
  pdf(paste0('Results/TotalSpecificDEG.',condition,'.pdf'),width = width,height = height)
  par(mfrow=c(1,2))
  par(mar=c(2.7,2.1,4,0.5))
  barplot(height = rev(TotalSpecRatio$total),col='lightgreen',xlim=c(max(TotalSpecRatio$total),0),
          horiz=TRUE,main = paste0('Number of DEG\n',condition))
  par(mar=c(2.7,1,4,2.1))
  b <- barplot(height = rev(TotalSpecRatio$specific_percent),col='grey',
               horiz=TRUE,main = paste0('Transcriptome-specific DEG, %\n',condition))
  mtext((c(nrow(TotalSpecRatio):1)), side=2, line=.25, at = b,las=2)
  dev.off()
}

RmetricPlot <- function(TotalSpecRatio, width=8,height=6){
  dir.create('Results')
  pdf(paste0('Results/RmetricPlot.',condition,'.pdf'),width = width,height = height)
  par(mfrow=c(1,2))
  par(mar=c(2.7,2.1,4,0.5))
  barplot(height = rev(TotalSpecRatio$total),col='lightgreen',xlim=c(max(TotalSpecRatio$total),0),
          horiz=TRUE,main = paste0('Number of DEG\n',condition))
  par(mar=c(2.7,1,4,2.1))
  b <- barplot(height = rev(TotalSpecRatio$Rmetric),col='grey',
               horiz=TRUE,main = paste0('R metric\n',condition))
  mtext((c(nrow(TotalSpecRatio):1)), side=2, line=.25, at = b,las=2)
  dev.off()
}

getCI <- function(bootstrap_results, condition = condition, m = (length(bootstrap_results)+1),
                  left_quantile = 0.025,right_quantile = 0.975){
  CI <- data.frame(matrix(nrow = 0,ncol=4))
  colnames(CI) <- c('LeftQuantile','RightQuantile','Name1','Name2')
  for (i in c(length(bootstrap_results)):1){
    lq = quantile(bootstrap_results[[i]],left_quantile)
    rq = quantile(bootstrap_results[[i]],right_quantile)
    CI0 <- data.frame('LeftQuantile' = lq,
                      'RightQuantile' = rq,
                      'Name1' = paste0(condition,'_',m,'vs',condition,'_',i),
                      'Name2' = paste0(m,'vs',i))
    CI <- rbind(CI, CI0)
  }
  rownames(CI) <- NULL
  return(CI)
}


#_____________________________________________________________
#Start here.

##Step 0. Data preparation.
##Initial table column format: Gene IDs, FC1, FDR1, FC2, FDR2, etc.
##Prepare merged table from separate output files using DE_weave(),
##generated by limma or DESeq2, if needed.

profiles0 <- DE_weave()

#Prepare metadata table for labeling or ordering. 
#Format: Experiment name/code, experiment metadata, column with custom order.
#This step can be skipped if simple numeric labels are enough.
#Metadata rows MUST have the same order as the experiments in profile table.

#__________________________________________________________
Profiles <- Signifs <- Descriptions <-  Melts <- DEG_lists <- list()
TotalSpecRatio_list <- Specific_DEGs_list <- Heatmaps <- Sim_matrixes <- list()
Bootstraps <- CIs <- list()

#Specify FDR threshold 
FDR_cutoff = 0.05
#Specify a condition to load correct files.
condition = 'Auxin' # Test examples: 'Ethylene' or 'Auxin'
#Load differential expression profile.
#It should has [ID, logFC1, FDR1, logFC2, FDR2...] format.
profiles0 <- fread(paste0(condition,'_Profiles.csv'),data.table=F)
rownames(profiles0) <- profiles0[,1]
Profiles[[condition]] <- profiles0
#Preparing a "significant" table.
#In such table only significant logFC values kept.
sgnf <- SignifTable(profiles0,FDR_cutoff=FDR_cutoff,logFC_cutoff = 0)
Signifs[[condition]] <- sgnf

#Or alternatively, load already prepared table with only significant values.
Auxin_ST1 <- read.csv('Auxin_ST1.csv',header = T,stringsAsFactors = F,sep=';')
rownames(Auxin_ST1) <- Auxin_ST1$TAIR.ID
Auxin_ST1 <- Auxin_ST1[,8:30]
#Auxin_ST1 <- Auxin_ST1 %>% select(14, 5, 7, 18, 19, 13, 6, 12, 21)
Signifs[[condition]] <- Auxin_ST1

#Get number of DEGs in each experiment.
DEG_number_per_exp <- data.frame(nDEGs = DEGsPerExperiment(Signifs[[condition]]))
#Get number of the experiments in which the gene is DEG.
exp_number_per_DEG <- data.frame(nEXPs = ExperimentsPerDEG(Signifs[[condition]]))
#Get all DEGs. 
DEGs <- data.frame(DEGs = rownames(exp_number_per_DEG))
#Restore IDs.
Signifs[[condition]]$ID <- rownames(Signifs[[condition]])
#Melting.
Melts[[condition]] <- melt(Signifs[[condition]],na.rm = T,id.vars = 'ID',
                     variable.name = 'exp',value.name = 'logFC')

#Specific/total ratio calculation.
TotalSpecRatio <- DE_summary(melted_table = Melts[[condition]])[[1]]
TotalSpecRatio_list[[condition]] <- TotalSpecRatio
Specific_DEGs <- DE_summary(Melts[[condition]])[[2]]
Specific_DEGs_list[[condition]] <- Specific_DEGs
TotalSpecRatio

TotalSpecPlot(TotalSpecRatio)
RmetricPlot(TotalSpecRatio)

#Skip this step if you need only numerical names for your profiles.
Descr <- fread(paste0(condition,'_Description.csv'),data.table = F)
#Specify column indexes to create tag/name for each experiment.
#You can use it to replace numerical names in the plots.
Descr$Study <- do.call(paste, c(Descr[c(3:8)], sep="."))
Descr$DEGs <- TotalSpecRatio$total
Descr$Specific_DEGs <- paste0(TotalSpecRatio$specific_percent,'%')
write.table(Descr,paste0(condition,'_Description_Updated.csv'),sep=';',row.names = F,quote = F)
#Auxin names for clustering.
Descr$Name_Clust <- paste(Descr$Order,Descr$Method,Descr$Organ,
                          Descr$Age,Descr$Conc,Descr$Time,
                          Descr$Agent,Descr$DEGs,
                          Descr$Specific_DEGs,sep='\n')
Descriptions[[condition]] <- Descr

#Technical step: table to list. 
DEG_list <- GetDEGLists(Melts[[condition]])
names(DEG_list) <- Descriptions[[condition]]$Study
DEG_lists[[condition]] <- DEG_list

#Heatmap plotting.
#Clustering = FALSE disables clustering, using previously specified order instead.
#You can find available clustering methods using ?hclust command.
#Default clustering method is ward.D2.
#Change the parameter "clustering_method" if needed.

#Specify tags: metric_heatmap(tags = Descr$Study) if needed. 
sim_matrix <- GetSimMatrix(DEG_lists[[condition]],metric='similarity',
                          tags = c(1:length(DEG_lists[[condition]])))
Sim_matrixes[[condition]] <- sim_matrix
sim_heatmap <- PlotSimHeatmap(sim_matrix,clustering = TRUE,clustering_method = 'complete')
Heatmaps[[condition]] <- sim_heatmap

pdf(paste0('Results/Auxin_heatmap.pdf'),width = 7.3,height = 6.6)
grid::grid.newpage()
grid::grid.draw(sim_heatmap$gtable)
dev.off()

#Clustering.
dir.create('Clustering',showWarnings=F)
#Change maximum threshold to max(exp_number_per_DEG), 
#if needed more clustering variants more "robust" DEGs
#based on the number of experiments in which this gene is DEG.
#for (i in (0:max(exp_number_per_DEG))){
for (i in (0:0)){
  threshold = i
  clustering_results <- DE_clustering(Profiles[[condition]],change_names_to = Descriptions[[condition]]$Name_Clust,
                                      iter = 5,FDR_cutoff = 0.05,
                                      threshold = threshold, insignif_to_zero = F)
  dend <- clustering_results[[1]] #dendrogram results
  dend_labels <- clustering_results[[2]] #dendrogram labels
  bb <- clustering_results[[3]] #bclust bootstrapping results
  df <- clustering_results[[4]] #data on which clustering was based
  
  pdf(paste0('Clustering/',condition,'.N',threshold,'.pdf'),
      width = 17, height = 6.9)
  par(mar=c(12, 5, 5, 3)+0.1)
  plot(dend, main = paste0('Clustering is based on ',nrow(df),
                           ' genes,\ndifferentially expressed in ',threshold,
                           ' and more experiments\nTreatment: ',condition),cex.main = 1.5)
  text(x = 1:length(dend_labels), y = rep(1,times=(length(dend_labels))),
       labels = dend_labels, srt = 0, pos = 1,offset=2,
       cex = 1.2, xpd = T)
  #text(x = length(dend_labels), y = 1.25*max(heights_per_k.dendrogram(dend)),pos = 1,xpd = T,
  #     labels = c('M - Microarray\nR - RNA-seq\nCbud - cauline bud\nRttip - Root tips\nRtHM - root segment\nbetween root meristem and\nroot-hypocotyl junction\nMerFl - meristem and young flowers\nSdl - Seedlings\nEtSdl - Etiolated seedlings\nN.DEGs - Number of DEGs\nSpecific - Percent of\ntranscriptome-specific DEGs'))
  text(x = -0.5, y = 1, pos = 1, offset =2, cex = 1.2, xpd = T, labels = c('Number\nMethod\nOrgan\nAge\nDose\nAgent\nTime\nN.DEGs\nSpecific'))
  Bclabels(bb$hclust, bb$values, pos=1,cex=1.2,offset=0.1)
  dev.off()
}

write.table(data.frame("N"=rownames(Sim_matrixes[[condition]]),TotalSpecRatio_list[[condition]]),
            paste0('Results/TotalSpecificRmetric_table_',condition,'.csv'),
            quote = F,row.names = F,sep=';')
write.table(data.frame("X"=paste0('X',rownames(Sim_matrixes[[condition]])),Sim_matrixes[[condition]]),
            paste0('Results/SimMatrix_',condition,'.csv'),
            quote = F,row.names = F,sep=';')
write.table(data.frame("ID" = rownames(exp_number_per_DEG),exp_number_per_DEG),
            paste0('Results/JointDEGs_',condition,'.csv'),
            quote = F,row.names = F,sep=';')


#______________________________________________________________
#______________________________________________________________
#______________________________________________________________

condition = 'Ethylene' # Test examples: 'Ethylene' or 'Auxin'
profiles0 <- fread(paste0(condition,'_Profiles.csv'),data.table=F)
rownames(profiles0) <- profiles0[,1]
Profiles[[condition]] <- profiles0
sgnf <- SignifTable(profiles0,FDR_cutoff=FDR_cutoff,logFC_cutoff = 0)
Signifs[[condition]] <- sgnf

Ethylene_ST2 <- read.csv('Ethylene_ST2.csv',header = T,stringsAsFactors = F,sep=';')
rownames(Ethylene_ST2) <- Ethylene_ST2$TAIR.ID
Ethylene_ST2 <- Ethylene_ST2[,7:22]
Signifs[[condition]] <- Ethylene_ST2

DEG_number_per_exp <- data.frame(nDEGs = DEGsPerExperiment(Signifs[[condition]]))
exp_number_per_DEG <- data.frame(nEXPs = ExperimentsPerDEG(Signifs[[condition]]))
DEGs <- data.frame(DEGs = rownames(exp_number_per_DEG))
Signifs[[condition]]$ID <- rownames(Signifs[[condition]])
Melts[[condition]] <- melt(Signifs[[condition]],na.rm = T,id.vars = 'ID',
                     variable.name = 'exp',value.name = 'logFC')

TotalSpecRatio <- DE_summary(melted_table = Melts[[condition]])[[1]]
TotalSpecRatio_list[[condition]] <- TotalSpecRatio
Specific_DEGs <- DE_summary(Melts[[condition]])[[2]]
Specific_DEGs_list[[condition]] <- Specific_DEGs
TotalSpecRatio

TotalSpecPlot(TotalSpecRatio)
RmetricPlot(TotalSpecRatio)

Descr <- fread(paste0(condition,'_Description.csv'),data.table = F)
#Specify column indexes to create tag/name for each experiment.
#You can use it to replace numerical names in the plots.
Descr$Study <- do.call(paste, c(Descr[c(3:8)], sep="."))
Descr$DEGs <- TotalSpecRatio$total
Descr$Specific_DEGs <- paste0(TotalSpecRatio$specific_percent,'%')
write.table(Descr,paste0(condition,'_Description_Updated.csv'),sep=';',row.names = F,quote = F)
#Auxin names for clustering.
Descr$Name_Clust <- paste(Descr$Order,Descr$Method,Descr$Organ,
                          Descr$Age,Descr$Conc,Descr$Time,
                          Descr$Agent,Descr$DEGs,
                          Descr$Specific_DEGs,sep='\n')
Descriptions[[condition]] <- Descr

#To lists.
DEG_list <- GetDEGLists(Melts[[condition]])
names(DEG_list) <- Descriptions[[condition]]$Study
DEG_lists[[condition]] <- DEG_list

#Heatmap.
sim_matrix <- GetSimMatrix(DEG_lists[[condition]],metric='similarity',
                             tags = c(1:length(DEG_lists[[condition]])))
Sim_matrixes[[condition]] <- sim_matrix
sim_heatmap <- PlotSimHeatmap(sim_matrix,clustering = TRUE,clustering_method = 'complete')
Heatmaps[[condition]] <- sim_heatmap

pdf(paste0('Results/Ethylene_heatmap.pdf'),width = 7.3,height = 6.6)
grid::grid.newpage()
grid::grid.draw(sim_heatmap$gtable)
dev.off()

#Clustering.
for (i in (0:0)){
  threshold = i
  clustering_results <- DE_clustering(Profiles[[condition]],
                                      change_names_to = Descriptions[[condition]]$Name_Clust,
                                      iter = 5,FDR_cutoff = 0.05,
                                      threshold = threshold,insignif_to_zero = F)
  dend <- clustering_results[[1]] #dendrogram results
  dend_labels <- clustering_results[[2]] #dendrogram labels
  bb <- clustering_results[[3]] #bclust bootstrapping results
  df <- clustering_results[[4]] #data on which clustering was based
  
  pdf(paste0('Clustering/',condition,'.N',threshold,'.pdf'),
      width = 15, height = 6)
  par(mar=c(12, 5, 5, 3)+0.1)
  plot(dend, main = paste0('Clustering is based on ',nrow(df),
                           ' genes,\ndifferentially expressed in ',threshold,
                           ' and more experiments\nTreatment: ',condition),cex.main = 1.5)
  text(x = 1:length(dend_labels), y = rep(1,times=(length(dend_labels))),
       labels = dend_labels, srt = 0, pos = 1,offset=2,
       cex = 1.2, xpd = T)
  #text(x = length(dend_labels), y = 1.25*max(heights_per_k.dendrogram(dend)),pos = 1,xpd = T,
  #     labels = c('M - Microarray\nR - RNA-seq\nS - SOLiD\nSdl - Seedlings\nEtSdl - Etiolated seedlings\nN.DEGs - Number of DEGs\nSpecific - Percent of\ntranscriptome-specific DEGs'))
  
  text(x = -0.5, y = 1, pos = 1, offset =2, cex = 1.2, xpd = T, labels = c('Number\nMethod\nOrgan\nAge\nDose\nAgent\nTime\nN.DEGs\nSpecific'))
  Bclabels(bb$hclust, bb$values, pos=1,cex=1.2,offset=0.1)
  dev.off()
}

write.table(data.frame("N"=rownames(Sim_matrixes[[condition]]),TotalSpecRatio_list[[condition]]),
            paste0('Results/TotalSpecificRmetric_table_',condition,'.csv'),
            quote = F,row.names = F,sep=';')
write.table(data.frame("X"=paste0('X',rownames(Sim_matrixes[[condition]])),Sim_matrixes[[condition]]),
            paste0('Results/SimMatrix_',condition,'.csv'),
            quote = F,row.names = F,sep=';')
write.table(data.frame("ID" = rownames(exp_number_per_DEG),exp_number_per_DEG),
            paste0('Results/JointDEGs_',condition,'.csv'),
            quote = F,row.names = F,sep=';')

#___________________Bootstrap______________________
#___________________#########______________________

#The bootstrap procedure is used to evaluate the homogeneity of the transcriptome sets. 
#Testing all possible combinations Aux23vsAux22, Aux23vsAux21... etc.
#The procedure is extremely time consuming. 
#5000 iterations takes ~1 hour for all 4 analyses.
iters = 1000 # or 5000
condition = 'Auxin'
Bootstraps[[condition]] <- DE_bootstrap(melted_table1 = Melts[[condition]],iters = iters)
saveRDS(Bootstraps,paste0('Results/Bootstrap_results.rds'))
condition = 'Ethylene'
Bootstraps[[condition]] <- DE_bootstrap(melted_table1 = Melts[[condition]],iters = iters)
saveRDS(Bootstraps,paste0('Results/Bootstrap_results.rds'))

# For demonstration purposes:
# Choose some experiments to test the homogeneity of the smaller groups.
# Choosing 9 auxin transcriptomes (roots, 5�7, 12�14, 18, 19, 21);
# and 7 ethylene transcriptomes (ethiolated seedlings, 1�3, 5�8).

Signifs[['Auxin_9']] <- Signifs[['Auxin']][,c(5:7, 12:14, 18, 19, 21, 24)]
Signifs[['Ethylene_7']] <- Signifs[['Ethylene']][,c(1:3, 5:8,17)]
Melts[['Auxin_9']] <- melt(Signifs[['Auxin_9']],na.rm = T,id.vars = 'ID',
                           variable.name = 'exp',value.name = 'logFC')
Melts[['Ethylene_7']] <- melt(Signifs[['Ethylene_7']],na.rm = T,id.vars = 'ID',
                           variable.name = 'exp',value.name = 'logFC')

condition = 'Auxin_9'
Bootstraps[[condition]] <- DE_bootstrap(melted_table1 = Melts[[condition]],iters = iters)
saveRDS(Bootstraps,paste0('Results/Bootstrap_results.rds'))
condition = 'Ethylene_7'
Bootstraps[[condition]] <- DE_bootstrap(melted_table1 = Melts[[condition]],iters = iters)
saveRDS(Bootstraps,paste0('Results/Bootstrap_results.rds'))


Bootstraps <- readRDS(paste0('Results/Bootstrap_results.rds'))
conditions = c('Auxin','Auxin_9','Ethylene','Ethylene_7')
for (condition in conditions){
  CIs[[condition]] <- getCI(Bootstraps[[condition]],condition = condition)
  write.table(CIs[[condition]],paste0('Results/',condition,'_CI.csv'),sep=';',quote=F,row.names = F)
}

p11 <- ggplot(CIs[['Auxin']]) + 
  geom_segment(aes(x=c(1:22), xend=c(1:22), y=LeftQuantile, 
                   yend=RightQuantile), linewidth=3, color="orange") +
  theme_bw() +
  geom_hline(yintercept=0,color='red') +
  scale_x_continuous(breaks = c(1:22),labels = c(22:1)) +
  xlab(label = 'k') +
  ylab(label = 'd') +
  ylim(min(CIs[['Auxin']]$LeftQuantile,CIs[['Ethylene']]$LeftQuantile),
       max(CIs[['Auxin']]$RightQuantile,CIs[['Ethylene']]$RightQuantile))

p12 <- ggplot(CIs[['Auxin_9']]) + 
  geom_segment(aes(x=c(1:8), xend=c(1:8), y=LeftQuantile, 
                   yend=RightQuantile), linewidth=3, color="orange") +
  theme_bw() +
  geom_hline(yintercept=0,color='red') +
  scale_x_continuous(breaks = c(1:8),labels = c(8:1)) +
  xlab(label = 'k') +
  ylab(label = 'd') +
  ylim(min(CIs[['Auxin_9']]$LeftQuantile,CIs[['Ethylene_7']]$LeftQuantile),
       max(CIs[['Auxin_9']]$RightQuantile,CIs[['Ethylene_7']]$RightQuantile))

p21 <- ggplot(CIs[['Ethylene']]) + 
  geom_segment(aes(x=c(1:15), xend=c(1:15), y=LeftQuantile, 
                   yend=RightQuantile), linewidth=3, color="orange") +
  theme_bw() +
  geom_hline(yintercept=0,color='red') +
  scale_x_continuous(breaks = c(1:15),labels = c(15:1)) +
  xlab(label = 'k') +
  ylab(label = 'd') +
  ylim(min(CIs[['Auxin']]$LeftQuantile,CIs[['Ethylene']]$LeftQuantile),
       max(CIs[['Auxin']]$RightQuantile,CIs[['Ethylene']]$RightQuantile))

p22 <- ggplot(CIs[['Ethylene_7']]) + 
  geom_segment(aes(x=c(1:6), xend=c(1:6), y=LeftQuantile, 
                   yend=RightQuantile), linewidth=3, color="orange") +
  theme_bw() +
  geom_hline(yintercept=0,color='red') +
  scale_x_continuous(breaks = c(1:6),labels = c(6:1)) +
  xlab(label = 'k') +
  ylab(label = 'd') +
  ylim(min(CIs[['Auxin_9']]$LeftQuantile,CIs[['Ethylene_7']]$LeftQuantile),
       max(CIs[['Auxin_9']]$RightQuantile,CIs[['Ethylene_7']]$RightQuantile))

ggarrange(p11, p12, p21, p22, 
          labels = c("�", "�", "�","�"),
          ncol = 2, nrow = 2,widths = c(1.5,1))

ggsave(filename = paste0('Results/CI_hist.tiff'),
       width = 8, height = 5, device='tiff', dpi=300)


# If you need to make more specific comparisons, for example, if you're trying
# to determine if 23 auxin trancriptomes yeld more "joint" DEG in total than
# 16 ethylene trancriptomes just because of the "sample" size difference or
# because of the biological difference between two phytohormone treatments. 
iters = 1000
BS_res <- data.frame(matrix(ncol=0,nrow=iters))

sizes2 = 16
BS_res$Aux23vsAux16 <- DE_bootstrap(melted_table1 = Melts[['Auxin']],
                                     melted_table2 = Melts[['Auxin']],
                                     size1 = 23, sizes2 = c(16),iters = iters)[[sizes2]]
sizes2 = 16
BS_res$Aux16vsEt16 <- DE_bootstrap(melted_table1 = Melts[['Auxin']],
                                     melted_table2 = Melts[['Ethylene']],
                                     size1 = 16, sizes2 = c(16),iters = iters)[[sizes2]]

write.table(BS_res,paste0('Results/Bootstrap_',iters,'_iters_for_histogram.csv'),
          quote = F,row.names = F,sep=';')

#To reload, use the following.
BS_res <- fread(paste0('Results/Bootstrap_',iters,'_iters_for_histogram.csv'),data.table = F)

#Plot the specific comparisons.
PlotHistBootstrap(BS_res,column_name = 'Aux23vsAux16',breaks = 100,hist_name = '23 Auxin - 16 Auxin')
PlotHistBootstrap(BS_res,column_name = 'Aux16vsEt16',breaks = 100,hist_name = '16 Auxin - 16 Ethylene')