#Hannah's TVE 16S analysis
#Almost entirely based on DADA2 Pipeline 1.8 Walkthrough:
#https://benjjneb.github.io/dada2/tutorial.html
#with edits by Carly D. Kenkel and modifications by Nicola Kriefall

#~########################~#
##### PRE-PROCESSING #######
#~########################~#

#fastq files should have R1 & R2 designations for PE reads
#Also - some pre-trimming. Retain only PE reads that match amplicon primer. Remove reads containing Illumina sequencing adapters

#in Terminal home directory:
#following instructions of installing BBtools from https://jgi.doe.gov/data-and-tools/bbtools/bb-tools-user-guide/installation-guide/
#1. download BBMap package, sftp to installation directory
#2. untar:
#tar -xvzf BBMap_(version).tar.gz
#3. test package:
#cd bbmap
#~/bin/bbmap/stats.sh in=~/bin/bbmap/resources/phix174_ill.ref.fa.gz

# my adaptors for 16S, which I saved as "adaptors.fasta"
# >forward
# AATGATACGGCGACCAC
# >forwardrc
# GTGGTCGCCGTATCATT
# >reverse
# CAAGCAGAAGACGGCATAC
# >reverserc
# GTATGCCGTCTTCTGCTTG

#primers for 16S:
# >forward
# GTGYCAGCMGCCGCGGTA
# >reverse
# GGACTACHVGGGTWTCTAAT

##Still in terminal - making a sample list based on the first phrase before the underscore in the .fastq name
#ls *R1_001.fastq | cut -d '_' -f 1 > samples.list

##cuts off the extra words in the .fastq files
#for file in $(cat samples.list); do  mv ${file}_*R1*.fastq ${file}_R1.fastq; mv ${file}_*R2*.fastq ${file}_R2.fastq; done

##gets rid of reads that still have the adaptor sequence, shouldn't be there, I didn't have any
#for file in $(cat samples.list); do ~/bin/bbmap/bbduk.sh in1=${file}_R1.fastq in2=${file}_R2.fastq ref=adaptors.fasta out1=${file}_R1_NoIll.fastq out2=${file}_R2_NoIll.fastq; done &>bbduk_NoIll.log

##getting rid of first 4 bases (degenerate primers created them)
#for file in $(cat samples.list); do ~/bin/bbmap/bbduk.sh in1=${file}_R1_NoIll.fastq in2=${file}_R2_NoIll.fastq ftl=4 out1=${file}_R1_NoIll_No4N.fastq out2=${file}_R2_NoIll_No4N.fastq; done &>bbduk_No4N.log

##only keeping reads that start with the 16S primer
#for file in $(cat samples.list); do ~/bin/bbmap/bbduk.sh in1=${file}_R1_NoIll_No4N.fastq in2=${file}_R2_NoIll_No4N.fastq restrictleft=20 k=10 literal=GTGYCAGCMGCCGCGGTA,GGACTACHVGGGTWTCTAAT copyundefined=t outm1=${file}_R1_NoIll_No4N_16S.fastq outu1=${file}_R1_check.fastq outm2=${file}_R2_NoIll_No4N_16S.fastq outu2=${file}_R2_check.fastq; done &>bbduk_16S.log
##higher k = more reads removed, but can't surpass k=20 or 21

##using cutadapt to remove primer
# for file in $(cat samples.list)
# do
# cutadapt -g GTGYCAGCMGCCGCGGTA -a ATTAGAWACCCVHGTAGTCC -G GGACTACHVGGGTWTCTAAT -A TACCGCGGCKGCTGRCAC -n 2 --discard-untrimmed -o ${file}_R1.fastq -p ${file}_R2.fastq ${file}_R1_NoIll_No4N_16S.fastq ${file}_R2_NoIll_No4N_16S.fastq
# done &> clip.log
##-g regular 5' forward primer
##-G regular 5' reverse primer
##-o forward out
##-p reverse out
##-max-n 0 means 0 Ns allowed
##this overwrote my original renamed files

# did sftp of *_R1.fastq & *_R2.fastq files to the folder to be used in dada2

# the 16s files for the pre-stress timepoint are here on scc: /projectnb/davies-hb/hannah/TVE_16S_ITS/tve_prestress_files/lane1and2_16S

#~########################~#
##### DADA2 BEGINS #########
#~########################~#

# ran into issues downstream, need to install & load more recent version of dada2:
# library(devtools)
# devtools::install_github("benjjneb/dada2")

library(dada2); packageVersion("dada2")
#Version 1.21.0
library(ShortRead); packageVersion("ShortRead")
#1.46.0
library(Biostrings); packageVersion("Biostrings")
#2.56.0

path <- "/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress/fastqs" # CHANGE ME to the directory containing the fastq files after unzipping.

fnFs <- sort(list.files(path, pattern = "R1_16S_final.fastq", full.names = TRUE))
fnRs <- sort(list.files(path, pattern = "R2_16S_final.fastq", full.names = TRUE))

get.sample.name <- function(fname) strsplit(basename(fname), "_")[[1]][1]
sample.names <- unname(sapply(fnFs, get.sample.name))
head(sample.names)
sample.names

#### check for primers ####
FWD <- "GTGYCAGCMGCCGCGGTA"  ## CHANGE ME to your forward primer sequence
REV <- "GGACTACHVGGGTWTCTAAT"  ## CHANGE ME...

allOrients <- function(primer) {
  # Create all orientations of the input sequence
  require(Biostrings)
  dna <- DNAString(primer)  # The Biostrings works w/ DNAString objects rather than character vectors
  orients <- c(Forward = dna, Complement = complement(dna), Reverse = reverse(dna),
               RevComp = reverseComplement(dna))
  return(sapply(orients, toString))  # Convert back to character vector
}
FWD.orients <- allOrients(FWD)
REV.orients <- allOrients(REV)
FWD.orients
REV.orients

fnFs.filtN <- file.path(path, "filtN", basename(fnFs)) # Put N-filterd files in filtN/ subdirectory
fnRs.filtN <- file.path(path, "filtN", basename(fnRs))
filterAndTrim(fnFs, fnFs.filtN, fnRs, fnRs.filtN, maxN = 0, multithread = TRUE)

primerHits <- function(primer, fn) {
  # Counts number of reads in which the primer is found
  nhits <- vcountPattern(primer, sread(readFastq(fn)), fixed = FALSE)
  return(sum(nhits > 0))
}
rbind(FWD.ForwardReads = sapply(FWD.orients, primerHits, fn = fnFs.filtN[[40]]),
      FWD.ReverseReads = sapply(FWD.orients, primerHits, fn = fnRs.filtN[[40]]),
      REV.ForwardReads = sapply(REV.orients, primerHits, fn = fnFs.filtN[[40]]),
      REV.ReverseReads = sapply(REV.orients, primerHits, fn = fnRs.filtN[[40]]))
#some files have a couple primers - weird but doesn't seem to be a reason for concern

#### Visualizing raw data ####

#First, lets look at quality profile of R1 reads
plotQualityProfile(fnFs.filtN[c(1,2,3,4)])
plotQualityProfile(fnFs.filtN[c(94,95,96,97)])
#looks mostly good up to 180 I think

#Then look at quality profile of R2 reads
plotQualityProfile(fnRs.filtN[c(1,2,3,4)])
plotQualityProfile(fnRs.filtN[c(94,95,96,97)])
#170 again

# Make directory and filenames for the filtered fastqs
filt_path <- file.path(path, "trimmed")
if(!file_test("-d", filt_path)) dir.create(filt_path)
filtFs <- file.path(filt_path, paste0(sample.names, "_F_filt.fastq.gz"))
filtRs <- file.path(filt_path, paste0(sample.names, "_R_filt.fastq.gz"))

#changing a bit from default settings - maxEE=1 (1 max expected error, more conservative), truncating length at 200 bp for both forward & reverse [leaves ~50bp overlap], added "trimleft" to cut off primers [18 for forward, 20 for reverse]
out <- filterAndTrim(fnFs, filtFs, fnRs, filtRs,
                     truncLen=c(175,175), #leaves ~50bp overlap
                     maxN=0, #DADA does not allow Ns
                     maxEE=c(1,1), #allow 1 expected errors, where EE = sum(10^(-Q/10)); more conservative, model converges
                     truncQ=2,
                     #trimLeft=c(18,20), #N nucleotides to remove from the start of each read
                     rm.phix=TRUE, #remove reads matching phiX genome
                     matchIDs=TRUE, #enforce matching between id-line sequence identifiers of F and R reads
                     compress=TRUE, multithread=TRUE) # On Windows set multithread=FALSE

head(out)
tail(out)

# Had to make the trimmed files on the cluster because of lack of space on my local machine
# Did this here:
# "/projectnb/davies-hb/hannah/TVE_16S_ITS/tve_prestress_files/lane1and2_16S/fastqs"
# by qsub'ing the trimmed_files_R file

#~############################~#
##### Learn Error Rates ########
#~############################~#

#setDadaOpt(MAX_CONSIST=30) #increase number of cycles to allow convergence
errF <- learnErrors(filtFs, multithread=TRUE)
errR <- learnErrors(filtRs, multithread=TRUE)

#sanity check: visualize estimated error rates
#error rates should decline with increasing qual score
#red line is based on definition of quality score alone
#black line is estimated error rate after convergence
#dots are observed error rate for each quality score

plotErrors(errF, nominalQ=TRUE)
plotErrors(errR, nominalQ=TRUE)

#~############################~#
##### Dereplicate reads ########
#~############################~#
#Dereplication combines all identical sequencing reads into ???unique sequences??? with a corresponding ???abundance???: the number of reads with that unique sequence.
#Dereplication substantially reduces computation time by eliminating redundant comparisons.
#DADA2 retains a summary of the quality information associated with each unique sequence. The consensus quality profile of a unique sequence is the average of the positional qualities from the dereplicated reads. These quality profiles inform the error model of the subsequent denoising step, significantly increasing DADA2???s accuracy.
derepFs <- derepFastq(filtFs, verbose=TRUE)
derepRs <- derepFastq(filtRs, verbose=TRUE)
# Name the derep-class objects by the sample names
names(derepFs) <- sample.names
names(derepRs) <- sample.names

#~###############################~#
##### Infer Sequence Variants #####
#~###############################~#

dadaFs <- dada(derepFs, err=errF, multithread=TRUE)
dadaRs <- dada(derepRs, err=errR, multithread=TRUE)

#now, look at the dada class objects by sample
#will tell how many 'real' variants in unique input seqs
#By default, the dada function processes each sample independently, but pooled processing is available with pool=TRUE and that may give better results for low sampling depths at the cost of increased computation time. See our discussion about pooling samples for sample inference.
dadaFs[[1]]
dadaRs[[1]]

#~############################~#
##### Merge paired reads #######
#~############################~#

#To further cull spurious sequence variants
#Merge the denoised forward and reverse reads
#Paired reads that do not exactly overlap are removed

mergers <- mergePairs(dadaFs, derepFs, dadaRs, derepRs, verbose=TRUE)
# Inspect the merger data.frame from the first sample
head(mergers[[1]])

summary((mergers[[1]]))

#We now have a data.frame for each sample with the merged $sequence, its $abundance, and the indices of the merged $forward and $reverse denoised sequences. Paired reads that did not exactly overlap were removed by mergePairs.

#~##################################~#
##### Construct sequence table #######
#~##################################~#
#a higher-resolution version of the ???OTU table??? produced by classical methods

seqtab <- makeSequenceTable(mergers)
dim(seqtab)
#[1]   175 11474

# Inspect distribution of sequence lengths
table(nchar(getSequences(seqtab)))

plot(table(nchar(getSequences(seqtab)))) #real variants appear to be right in that 244-264 window

#The sequence table is a matrix with rows corresponding to (and named by) the samples, and
#columns corresponding to (and named by) the sequence variants.
#Sequences that are much longer or shorter than expected may be the result of non-specific priming, and may be worth removing

# trying to figure out what these two peaks are, make seq tables of both peaks
seqtab2 <- seqtab[,nchar(colnames(seqtab)) %in% seq(240,260)] #again, being fairly conservative wrt length

#~############################~#
##### Remove chimeras ##########
#~############################~#
#The core dada method removes substitution and indel errors, but chimeras remain.
#Fortunately, the accuracy of the sequences after denoising makes identifying chimeras easier
#than it is when dealing with fuzzy OTUs: all sequences which can be exactly reconstructed as
#a bimera (two-parent chimera) from more abundant sequences.

seqtab.nochim <- removeBimeraDenovo(seqtab2, method="consensus", multithread=TRUE, verbose=TRUE)
dim(seqtab.nochim)
#Identified 801 bimeras out of 9420 input sequences.

#The fraction of chimeras varies based on factors including experimental procedures and sample complexity,
#but can be substantial.
sum(seqtab.nochim)/sum(seqtab2)
#0.9924602

saveRDS(seqtab.nochim, file="/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress/tve16s_prestress_seqtab.nochim.rds")
write.csv(seqtab.nochim, file="/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress/tve16s_prestress_seqtab.nochim.csv")

#~############################~#
##### Track Read Stats #########
#~############################~#

# note that because I created the trimmed files on the cluster, I can't make this file here. But the older version is still relevant (just has the lineage 3 individuals included)
getN <- function(x) sum(getUniques(x))
track <- cbind(out, sapply(dadaFs, getN), sapply(mergers, getN), rowSums(seqtab2), rowSums(seqtab.nochim))
colnames(track) <- c("input", "filtered", "denoised", "merged", "tabled", "nonchim")
rownames(track) <- sample.names
head(track)
tail(track)

write.csv(track,file="/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress/tve16s_prestress_readstats.csv",row.names=TRUE,quote=FALSE)

#~############################~#
##### Assign Taxonomy ##########
#~############################~#

#Assign Taxonomy
# downloaded most recent silva files from here: https://zenodo.org/record/4587955#.Yd8ZRxPMJmo

# scp seqtab.nochim.rds file to scc

# this step had to happen on the SCC because it took too much memory to run locally.
# on scc: /projectnb/davies-hb/hannah/TVE_16S_ITS/tve_prestress_files/lane1and2_16S/assign_tax

# first, module load R and type R to open interactive window.
# next, install dada2 using biocmanager
# then submit the job "assign_tax_R" using qsub.

# scp the .rds files back to local machine when finished running

# here is how I would do it locally if it didn't take too much memory:
taxa <- assignTaxonomy(seqtab.nochim, "/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress_Timepoint/silva_nr_v132_train_set.fa.gz",tryRC=TRUE)
unname(head(taxa))
taxa.plus <- addSpecies(taxa, "/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress_Timepoint/silva_species_assignment_v132.fa.gz",tryRC=TRUE,verbose=TRUE)
# 247 out of 2608 were assigned to the species level.
# Of which 223 had genera consistent with the input table.

saveRDS(taxa.plus, file="/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress_Timepoint/tve16s_prestress_taxaplus.rds")
saveRDS(taxa, file="/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress_Timepoint/tve16s_prestress_taxa.rds")
#write.csv(taxa.plus, file="mr16s_taxaplus.csv")
#write.csv(taxa, file="mr16s_taxa.csv")

#### Read in previously saved datafiles ####
setwd("/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress")

seqtab.nochim <- readRDS("tve16s_prestress_seqtab.nochim.rds")
taxa <- readRDS("tve16s_prestress_seq_taxa.rds")
#taxa.plus <- readRDS("mr16s_revised_taxaplus.rds")

# check for samples with 0 reads - I2C4 is a culprit
rowSums(seqtab.nochim)

row_names_to_remove<-c("I2C4") # I2C4 being removed because of 0 reads, ITS because they were negative controls specific to ITS
seqtab.nochim <- seqtab.nochim[!(row.names(seqtab.nochim) %in% row_names_to_remove),]

#~############################~#
##### handoff 2 phyloseq #######
#~############################~#

#BiocManager::install("phyloseq")
library('phyloseq')
library('ggplot2')
library('Rmisc')
library('cowplot')
library('ShortRead')
library('dplyr')

#import dataframe holding sample information
samdf <- read.csv("SampleInfo_noL3.csv")
# add identifying data
phys_metadata = read.csv("/Users/hannahaichelman/Documents/BU/TVE/phys_metadata.csv")
phys_metadata = phys_metadata %>%
  filter(treat != "Initial")
# comine with samdf
samdf = left_join(samdf, phys_metadata, by = "frag")
#write.csv(samdf, file = "samdf_noL3.csv")

samdf = samdf %>%
  filter(frag != "I2C4")

head(samdf)
rownames(samdf) <- samdf$frag

# Construct phyloseq object (straightforward from dada2 outputs)
ps <- phyloseq(otu_table(seqtab.nochim, taxa_are_rows=FALSE),
               sample_data(samdf),
               tax_table(taxa))

ps
# 8619 taxa and 174 samples

#### first look at data ####
ps_glom <- tax_glom(ps, "Family")
plot_bar(ps_glom, x="sitename", fill="Family")+
  theme(legend.position="none")

#phyloseq object with shorter names - doing this one instead of one above
ids <- paste0("sq", seq(1, length(colnames(seqtab.nochim))))

#making output fasta file for lulu step & maybe other things
library(dada2)
path='/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress/tve16s_prestress.fasta'
uniquesToFasta(seqtab.nochim, path, mode = "w", width = 20000)

colnames(seqtab.nochim)<-ids
taxa2 <- cbind(taxa, rownames(taxa)) #retaining raw sequence info before renaming
rownames(taxa2)<-ids

#phyloseq object with new taxa ids
ps <- phyloseq(otu_table(seqtab.nochim, taxa_are_rows=FALSE),
               sample_data(samdf),
               tax_table(taxa2))

ps #8619 taxa and 174 samples

#save(taxa2,file="taxa2.Rdata")

#### remove mitochondria, chloroplasts, non-bacteria ####
ps.mito <- subset_taxa(ps, (Family=="Mitochondria"))
ps.mito #161 taxa to remove
ps.chlor <- subset_taxa(ps, (Order=="Chloroplast"))
ps.chlor #583 taxa to remove
ps.notbact <- subset_taxa(ps, (Kingdom!="Bacteria") | is.na(Kingdom))
ps.notbact #41 taxa to remove

ps.nomito <- subset_taxa(ps, (Family!="Mitochondria") | is.na(Family))
ps.nomito #8458 taxa
ps.nochlor <- subset_taxa(ps.nomito, (Order!="Chloroplast") | is.na(Order))
ps.nochlor #7875 taxa
ps.clean <- subset_taxa(ps.nochlor, (Kingdom=="Bacteria"))
ps.clean #7834 taxa

#just archaea
ps.arch <- subset_taxa(ps.nomito, (Kingdom=="Archaea"))
ps.arch #41 taxa

#### identifying contamination ####
#install.packages("decontam")
library(decontam)

df <- as.data.frame(sample_data(ps.clean)) # Put sample_data into a ggplot-friendly data.frame
df$LibrarySize <- sample_sums(ps.clean)
df <- df[order(df$LibrarySize),]
df$Index <- seq(nrow(df))
ggplot(data=df, aes(x=Index, y=LibrarySize, color=sitename)) + geom_point()

sample_data(ps.clean)$is.neg <- sample_data(ps.clean)$Sample_or_Control == "Control"
contamdf.prev <- isContaminant(ps.clean, neg="is.neg",threshold=0.5)
table(contamdf.prev$contaminant)
# FALSE  TRUE
# 7680   154

# Make phyloseq object of presence-absence in negative controls and true samples
ps.pa <- transform_sample_counts(ps.clean, function(abund) 1*(abund>0))
ps.pa.neg <- prune_samples(sample_data(ps.pa)$Sample_or_Control == "Control", ps.pa)
ps.pa.pos <- prune_samples(sample_data(ps.pa)$Sample_or_Control == "Control", ps.pa)
# Make data.frame of prevalence in positive and negative samples
df.pa <- data.frame(pa.pos=taxa_sums(ps.pa.pos), pa.neg=taxa_sums(ps.pa.neg),
                    contaminant=contamdf.prev$contaminant)
ggplot(data=df.pa, aes(x=pa.neg, y=pa.pos, color=contaminant)) + geom_point() +
  xlab("Prevalence (Negative Controls)") + ylab("Prevalence (True Samples)")

#remove from ps.clean:
ps.clean1 <- prune_taxa(!contamdf.prev$contaminant,ps.clean)
#also remove negative controls, don't need them anymore I think
ps.cleaner <- subset_samples(ps.clean1,(Sample_or_Control!="Control"))

#### blast asvs to NCBI to see if any eukaryotes got through ####
##Running blast on BU SCC to make organism match files for my 16s data
##used 'tve16s_prestress.fasta' made above
## Working here on cluster:
# /projectnb/davies-hb/hannah/TVE_16S_ITS/tve_prestress_files/lane1and2_16S/euk_blast

# have to split fasta file up to make it run faster
#awk -v size=5000 -v pre=tve16s_prestress_split -v pad=5 '/^>/{n++;if(n%size==1){close(f);f=sprintf("%s.%0"pad"d",pre,n)}}{print>>f}' tve16s_prestress.fasta

#module load blast+
##submitted the following array job: qsub split_blast_array.qsub
#made that qsub file by doing this, make sure to add -pe omp 10:
#scc6_qsub_launcher.py -N split_blast -P coral -M haich@bu.edu -j y -h_rt 64:00:00 -jobsfile split_blast

# [haich@scc1 euk_blast]$ cat split_blast
# blastn -query tve16s_prestress_split.00001 -db nt -outfmt "6 std staxids sskingdoms" -evalue 1e-5 -max_target_seqs 5 -out tve16s_prestress_split.00001_taxids.out -remote
# blastn -query tve16s_prestress_split.05001 -db nt -outfmt "6 std staxids sskingdoms" -evalue 1e-5 -max_target_seqs 5 -out tve16s_prestress_split.05001_taxids.out -remote


##takes a very long time (Nicola had ~2600 ASVs, took 11 hours)
# when job finishes, concatenate the split output files into one
# [haich@scc1 euk_blast]$ cat tve16s_prestress_split.00001_taxids.out tve16s_prestress_split.05001_taxids.out > tve16s_prestress_split_taxids.out

##now getting taxonomy info:

# #download/install taxonkit things, more instructions here:
# #https://bioinf.shenwei.me/taxonkit/usage/

# cd /net/scc-pa2/scratch/
# wget -c ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
# tar -zxvf taxdump.tar.gz
# cd
# [haich@scc1 taxa]$ cp *.dmp /usr3/graduate/haich/.taxonkit

# module load miniconda
# conda install -c bioconda taxonkit -p .
# cd /net/scc-pa2/scratch/taxa/
# cp *.dmp ~/.taxonkit
# #command taxonkit should work now

##extracting taxa ids from blast output for taxonkit:
# awk -F " " '{print $13}' tve16s_prestress_split_taxids.out > ids
# taxonkit lineage ids > ids.tax
# cut -f1 tve16s_prestress_split_taxids.out > ids.seq; paste ids.seq ids.tax > ids.seq.tax
# grep "Eukaryota" ids.seq.tax | cut -f1 | sort | uniq > euk.contam.asvs

##transferring euk.contam.asvs to back here
##remove from ps.cleaner
##should be 151 to remove
euks <- read.csv("euk.contam.asvs.csv",header=FALSE)
euks_names <- euks$V1
alltaxa <- taxa_names(ps.cleaner) #should be 7680
keepers <- alltaxa[(!alltaxa %in% euks_names)] #doesn't look like any were removed
ps.cleanest <- prune_taxa(keepers, ps.cleaner)
#7680 taxa and 172 samples

seqtab.cleanest <- data.frame(otu_table(ps.cleanest))
#write.csv(seqtab.cleanest,file="tve16s_seqtab.rev.cleanest.csv")

##save cleaned phyloseq object
saveRDS(ps.cleanest,file="phyloseq.cleanest.rds")

#### Decontaminated (Euk contamination removed) files ####
setwd("/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress")
ps.cleanest = readRDS("phyloseq.cleanest.rds")
seqtab.cleanest <- data.frame(ps.cleanest@otu_table)
samdf.cleanest <- data.frame(ps.cleanest@sam_data)

#### rarefy decontaminated data #####
library(vegan)
load("taxa2.Rdata")
# more info on rarefying: https://micca.readthedocs.io/en/latest/phyloseq.html
# plot rarefaction curve
rarecurve(seqtab.cleanest,step=100,label=TRUE) #after removing contaminants

# Plot reads per sample
df = data.frame(ASVs=rowSums(otu_table(ps.cleanest)>0), reads=sample_sums(ps.cleanest), sample_data(ps.cleanest))

ggplot(df, aes(x=reads)) +
  geom_histogram(bins=50, color='black', fill='grey') +
  theme_bw() +
  geom_vline(xintercept=10000, color= "red", linetype='dashed') +
  labs(title="Histogram: Reads per Sample") + xlab("Read Count") + ylab("Sample Count")

total <- rowSums(seqtab.cleanest)
subset(total, total <1000)
#28 samples at 2000 seqs
#5 samples at 1000 seqs
# Justification for 1000 seq cut-off for rarefying: https://www.nature.com/articles/s41467-018-07275-x

row.names.remove <- names(subset(total, total <1000))
seqtab.less <- seqtab.cleanest[!(row.names(seqtab.cleanest) %in% row.names.remove),]

samdf.rare <- samdf.cleanest[!(row.names(samdf.cleanest) %in% row.names.remove), ]

# rarefy to 1000 reads per sample
seqtab.rare <- rrarefy(seqtab.less,sample=1000)
rarecurve(seqtab.rare,step=100,label=TRUE)

#phyloseq object but rarefied
ps.rare <- phyloseq(otu_table(seqtab.rare, taxa_are_rows=FALSE),
                    sample_data(samdf.rare),
                    tax_table(taxa2))
ps.rare #7680 taxa and 167 samples

#removing missing taxa - lost after rarefying
ps.rare <- prune_taxa(taxa_sums(ps.rare) > 0, ps.rare)
ps.rare #5489 taxa and 167 samples with 1000 rarefy

seqtab.rare <- data.frame(otu_table(ps.rare))

#saving
saveRDS(ps.rare,file="phyloseq.rarefied.1k.rds")
#write.csv(seqtab.rare, file="tve16s_seqtab.rev.cleanest.rare_1k")

### data files - decontaminated, rarefied ####

setwd("/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress")
ps.rare.1k = readRDS("phyloseq.rarefied.1k.rds")
seqtab.rare.1k <- data.frame(ps.rare.1k@otu_table)
samdf.rare.1k <- data.frame(ps.rare.1k@sam_data)
load("taxa2.Rdata")

ps.rare <- phyloseq(otu_table(seqtab.rare.1k, taxa_are_rows=FALSE),
                    sample_data(samdf.rare.1k),
                    tax_table(taxa2))
ps.rare #5688 taxa and 178 samples

#### trim underrepresented otus ####
# don't use rarefied data for this
library(MCMC.OTU)

#formatting the table for mcmc.otu - requires one first column that's 1 through whatever
#& has "X" as column name
nums <- 1:nrow(seqtab.cleanest)
samples <- rownames(seqtab.cleanest)

int <- cbind(sample = 0, seqtab.cleanest)
seq.formcmc <- cbind(X = 0, int)

seq.formcmc$X <- nums
seq.formcmc$sample <- samples

seq.trim.allinfo <- purgeOutliers(seq.formcmc,count.columns=3:7682,sampleZcut=-2.5,otu.cut=0.0001,zero.cut=0.02)
#I2F1 has effed z-score (means it is a low coverage outlier)
#641 ASVs pass filters

#remove sample info
seq.trim <- seq.trim.allinfo[,3:643]

#write.csv(seq.trim,file="tve16s_seqtab.rev.cleanest.trim.csv")

#remake phyloseq objects
ps.trim <- phyloseq(otu_table(seq.trim, taxa_are_rows=FALSE),
                    sample_data(samdf.cleanest),
                    tax_table(taxa2))
ps.trim #641 taxa and 171 samples (one less than ps.cleanest because of I2F1 outlier)

#saveRDS(ps.trim,file="phyloseq.cleanest.trim.rds")

#### data files - trimmed ####
seq.trim <- read.csv("tve16s_seqtab.rev.cleanest.trim.csv",row.names=1)

#### rarefy trimmed data #####
library(vegan)

setwd("/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress")
ps.trim = readRDS("phyloseq.cleanest.trim.rds")
seqtab.trim <- data.frame(ps.trim@otu_table)
samdf.trim <- data.frame(ps.trim@sam_data)

rarecurve(seqtab.trim,step=100,label=TRUE)

total <- rowSums(seqtab.trim)
subset(total, total <1000)
#6 samples

row.names.remove <- names(subset(total, total <1000))
seqtab.less <- seqtab.trim[!(row.names(seqtab.trim) %in% row.names.remove),]

seqtab.trim.rare <- rrarefy(seqtab.less,sample=1000)
rarecurve(seqtab.trim.rare,step=100,label=TRUE)

#phyloseq object but rarefied & trimmed
ps.trim.rare <- phyloseq(otu_table(seqtab.trim.rare, taxa_are_rows=FALSE),
                         sample_data(samdf.trim),
                         tax_table(taxa2))
ps.trim.rare #641 taxa and 165 samples

#### data files - decontaminated, trimmed, rarefied ####
#saving
#write.csv(seqtab.trim.rare, file="tve16s_seqtab.rev.trim.rare_1k.csv")
#saveRDS(ps.trim.rare,file="phyloseq.trim.rare.rds")

#### making fasta file for picrust2 - trimmed not rarefied ####
library(phyloseq)
library(dada2)

#if needed:
setwd("/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress")

ps.trim = readRDS("phyloseq.cleanest.trim.rds")
seqtab.trim <- data.frame(ps.trim@otu_table)
samdf.trim <- data.frame(ps.trim@sam_data)
load("taxa2.Rdata")

ps.trim <- phyloseq(otu_table(seqtab.trim, taxa_are_rows=FALSE),
                    sample_data(samdf.trim),
                    tax_table(taxa2))
ps.trim #641 taxa and 171 samples

trim.otu <- as.matrix(ps.trim@otu_table)
trim.taxa <- data.frame(ps.trim@tax_table)
rownames(trim.taxa)==colnames(trim.otu)

colnames(trim.otu) <- trim.taxa$V8
ids <- rownames(trim.taxa)

path="/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_PreStress/tve16s_rev.cleanest.trimmed.fasta"
uniquesToFasta(trim.otu, path, ids = ids, mode = "w", width = 20000)

#re-formatting seq table so picrust likes it:
#a tab-delimited table with ASV ids as the first column and sample abundances as all subsequent columns
seqtab.trim.t <- t(seqtab.trim)
write.table(seqtab.trim.t,file="tve16s_seqtab.cleanest.trim.t.txt")
#manually removed the quotation marks that appeared in the file, and converted to tab delimited file from Excel

#### moving on to tve16s_diversity_analysis.R script in other folder ####

#### Try Batch Correction ####
## This step not necessary when including only the Pre-Stress data.
## This was useful when trying to analyze T0 and Pre-Stress data together.

cran.packages <- c('knitr', 'xtable', 'ggplot2', 'vegan', 'cluster',
                   'gridExtra', 'pheatmap', 'ruv', 'lmerTest', 'bapred')
install.packages(cran.packages)
bioconductor.packages <- c('sva', 'limma', 'AgiMicroRna',
                           'variancePartition', 'pvca')
if (!requireNamespace('BiocManager', quietly = TRUE))
  install.packages('BiocManager')
BiocManager::install(bioconductor.packages)

BiocManager::install("mixOmics", force = TRUE)

library(knitr)
library(xtable) # table
library(mixOmics)
library(sva) # ComBat
library(ggplot2) # PCA sample plot with density
library(gridExtra) # PCA sample plot with density
library(limma) # removeBatchEffect (LIMMA)
library(vegan) # RDA
library(AgiMicroRna) # RLE plot
library(cluster) # silhouette coefficient
library(variancePartition) # variance calculation
library(pvca) # PVCA
library(pheatmap) # heatmap
library(ruv) # RUVIII
library(lmerTest) # lmer
library(bapred) # FAbatch

setwd("/Users/hannahaichelman/Documents/BU/TVE/16S_ITS2/16S_All_Timepoints")

# data that is cleaned of euk contamination but nothing else
ps.cleanest = readRDS("phyloseq.cleanest.rds")
seqtab.cleanest <- data.frame(ps.cleanest@otu_table)
samdf.cleanest <- data.frame(ps.cleanest@sam_data)

# data that is cleaned and rarefied
ps.rare.1k = readRDS("phyloseq.rarefied.1k.rds")
seqtab.cleanest <- data.frame(ps.rare.1k@otu_table)
samdf.cleanest <- data.frame(ps.rare.1k@sam_data)

# data that is cleaned, trimmed, rarefied
ps.trim.rare = readRDS("phyloseq.trim.rare.rds")
seqtab.cleanest <- data.frame(ps.trim.rare@otu_table)
samdf.cleanest <- data.frame(ps.trim.rare@sam_data)


## Prefiltering
# ad data
seqtab.index.keep <- which(colSums(seqtab.cleanest)*100/(sum(colSums(seqtab.cleanest))) > 0.01)
seqtab.cleanest.keep <- seqtab.cleanest[, seqtab.index.keep]
dim(seqtab.cleanest.keep)
# [1]  237 1125

# Add offset to handle zeros
seqtab.cleanest.keep <- seqtab.cleanest.keep + 1

# Centered log-ratio transformation
seqtab.clr <- logratio.transfo(seqtab.cleanest.keep, logratio = 'CLR')
class(seqtab.clr) <- 'matrix'

## Batch effect detection
# pca
seqtab.pca.before <- pca(seqtab.clr, ncomp = 3)

data = as.data.frame(seqtab.pca.before$variates$X)
batch = as.factor(samdf.cleanest$time)
trt = as.factor(samdf.cleanest$treat)
expl.var = seqtab.pca.before$explained_variance

pMain <- ggplot(data = data, aes(x = data[ ,1], y = data[ ,2], colour = batch, shape = trt)) +
  geom_point()+
  xlab(paste0('PC1: ', round(as.numeric(expl.var[1])*100), '% expl.var')) +
  ylab(paste0('PC2: ', round(as.numeric(expl.var[2])*100), '% expl.var')) +
  scale_color_manual(values = color.mixo(1:10)) +
  theme_bw()+
  stat_ellipse()
#xlim(xlim[1], xlim[2]) +
#ylim(ylim[1], ylim[2]) +
#labs(colour = batch.legend.title, shape = trt.legend.title)
pMain
pTop <- ggplot(data,aes(x = data[ ,1], fill = batch, linetype = trt)) +
  geom_density(alpha = 0.5) +
  ylab('Density')
pRight <- ggplot(data, aes(x=data[ ,2], fill = batch, linetype=trt)) +
  geom_density(alpha = 0.5) +  coord_flip() + ylab('Density')

grid.arrange(pTop, pMain, pRight)



