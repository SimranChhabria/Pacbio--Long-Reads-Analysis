#!/bin/bash
#SBATCH -p bigmem
## number of cores
#SBATCH -n 24
#SBATCH -o long-reads-merged.out

#----
# conda activate long-read-seq
#----

#-----
# Specify paths
#-----


#--- Input files path --#
GENOME_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/ref_files/mouse_ref/GRCm39
CLUSTERED_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/20230914_Mira_LRseq/Mus_musculus/Merged_cells

#--- Results paths --#
RESULTS_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/20230914_Mira_LRseq/Mus_musculus/RESULTS-MC
PBMM2_DIR=$RESULTS_DIR/pbmm2
ISO_COLLAPSE_DIR=$RESULTS_DIR/iso-seq-collapse



# #---- Step 1 :Merge the two SMRT cells (AP1 and AP2) flnc bam files 
# # ---
# # Input   : flnc.bam files renamed (from isoseq-refine step)
# # Output  : flnc.fofn
# #-----
          
cd $CLUSTER_DIR
ls E4-sample03.flnc.bam E4-sample01.flnc.bam E4-sample02.flnc.bam E2_sample02.flnc.bam E2_sample03.flnc.bam E2_sample01.flnc.bam > flnc.fofn


# #--- Step 2: Isoseq3 cluster to Cluster FLNC reads and generate polished transcripts (HQ Transcript Isoforms) --#
# #---
# # Input  : flnc.fofn
# # Output : polished.bam
# #----

cd $CLUSTER_DIR
isoseq3 cluster flnc.fofn clustered.bam --verbose --use-qvs

# #----- Step 4: pbmm2 alignment -------#
# #--- 
# # Input  : clustered.hq.fasta.gz
# #          mouse_ref.fa
# # Output : aligned.sorted.bam
# #---

pbmm2 align $GENOME_DIR/GRCm39.primary_assembly.genome.fa $CLUSTERED_DIR/clustered.hq.fasta.gz $PBMM2_DIR/aligned.sort.bam --preset ISOSEQ --sort --log-level INFO


# #-- Step 4.1 : Get the alignment stats
# #--
# # Input  : aligned.sort.bam
# # Output :  
# #---

samtools view -h -o $PBMM2_DIR/aligned.sort.sam $PBMM2_DIR/aligned.sort.bam
htsbox samview -pS $PBMM2_DIR/aligned.sort.sam  > $PBMM2_DIR/aligned.paf

cd $PBMM2_DIR

awk -F'\t' '{if ($6="*") {print $0}}' aligned.paf > aligned.allread.paf # all reads
awk -F'\t' '{if ($6=="*") {print $0}}' aligned.paf > aligned.notread.paf
awk -F'\t' '{if ($6!="*") {print $0}}' aligned.paf > aligned.filtered.paf
awk -F'\t' '{print $1,$6,$8+1,$2,$4-$3,($4-$3)/$2,$10,($10)/($4-$3),$5,$13,$15,$17}' aligned.filtered.paf | sed -e s/"mm:i:"/""/g -e s/"in:i:"/""/g -e s/"dn:i:"/""/g | sed s/" "/"\t"/g > aligned"_reads_with_alignment_statistics.txt"
echo "Number of mapped transcripts to genome:"
wc -l aligned.filtered.paf
echo "Number of ummapped transcripts to genome:"
wc -l aligned.notread.paf


# #---- Step 5: Isoseq collapse : to collapse all the redundant transcripts
# #--
# # Input  : aligned.sort.sam
# # Output : collapsed fasta and gff file
# #----


isoseq3 collapse --log-level TRACE --do-not-collapse-extra-5exons --log-file $ISO_COLLAPSE_DIR/collapse_log $PBMM2_DIR/aligned.sort.bam $ISO_COLLAPSE_DIR/combined_collapse.gff


