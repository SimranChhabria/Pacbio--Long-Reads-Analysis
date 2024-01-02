#!/bin/bash
#SBATCH -p bigmem
## number of cores
#SBATCH -n 24
#SBATCH -o RNA-seq.out

#----
# Usage:
# conda activate long-read-seq
# 
#----

#-----
# Specify paths
#-----

#--- Input files path --#
FASTQ_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/20230711_Mira_RNAseq/fastq/RNA-seq
GENOME_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/ref_files/mouse_ref/GRCm39
ISO_COLLAPSE_DIR=$RESULTS_DIR/iso-seq-collapse

#--- Results paths --#
RESULTS_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/20230914_Mira_LRseq/Mus_musculus/RESULTS-MC
STAR_DIR=$RESULTS_DIR/STAR_BED
KALLISTO_DIR=$RESULTS_DIR/kallisto_ic



# #----- Step 1: Running STAR on RNA-seq fastq files for SJ.out.bed
# #---
# # Input  : STAR_index
# #          fastq files
# # Output : SJ.out.bed
# #----

# #---
# # Step 1.1 : Building index
# #----

mkdir -p $GENOMEDIR/STAR
STAR --runThreadN 23 --runMode genomeGenerate --genomeDir $GENOMEDIR/STAR --genomeFastaFiles $GENOMEDIR/GRCm39.primary_assembly.genome.fa --sjdbGTFfile $GENOMEDIR/gencode.vM31.primary_assembly.annotation.gtf

# #---
# # Step 1.2 : Running STAR
# #----


for fn in *_001.fastq.gz;
do
samplename=${fn%_001.fastq.gz}
echo "Processing sample ${samplename}"

mkdir $FASTQ_DIR/$samplename
cd $FASTQ_DIR/$samplename
STAR --runMode alignReads --runThreadN 32 --genomeDir $GENOMEDIR/STAR \
        --readFilesIn $FASTQ_DIR/$fn  \
        --outSAMtype BAM SortedByCoordinate \
        --chimSegmentMin 25 \
    	    --chimJunctionOverhangMin 20 \
    	    --chimOutType WithinBAM \
    	    --chimFilter banGenomicN \
    	    --twopassMode Basic \
    	    --twopass1readsN -1 \
        --readFilesCommand zcat 

picard MarkDuplicates INPUT=$samplename".sorted.bam" OUTPUT=$samplename".sorted.nodup.bam" METRICS_FILE=$samplename".dup.txt" VALIDATION_STRINGENCY=LENIENT REMOVE_DUPLICATES=true 2> $samplename.PicardDup.log

mv Aligned.sortedByCoord.out.bam $samplename.sorted.bam
mv Log.final.out $samplename.Log.final.out
mv Log.out $samplename.Log.out
mv Log.progress.out $samplename.Log.progress.out
mv SJ.out.tab $samplename.SJ.out.bed
mv $samplename.SJ.out.bed $STAR_DIR
done


# #--- Step 2 : Kallisto 
# #--
# # Input  : RNA-seq fastq files, Index from collapse.fasta
# # Output : combined_abundance.tsv 
# #----

# #---- Samples used ----#
# # sample10_S10_R1_001.fastq.gz sample11_S11_R1_001.fastq.gz sample12_S12_R1_001.fastq.gz sample14_S14_R1_001.fastq.gz sample15_S15_R1_001.fastq.gz sample16_S16_R1_001.fastq.gz
# # ---------

# # ** -- Building Index --**
kallisto index -i $KALLISTO_DIR/kallisto_index/kallisto_transcripts_ic.idx $ISO_COLLAPSE_DIR/combined_collapse.fasta


# # ** -- Kallisto Quantification --**
cd $FASTQ_DIR

for fn in *_001.fastq.gz;
do
samplename=${fn%_001.fastq.gz}
echo "Processing sample ${samplename}"
kallisto quant -i $KALLISTO_DIR/kallisto_index/kallisto_transcripts_ic.idx \
          -o $KALLISTO_DIR/${samplename} \
          --single -l 200 -s 25 $fn

mv $KALLISTO_DIR/${samplename}/abundance.tsv > $KALLISTO_DIR/${samplename}/${samplename}_abundance.tsv
done

# # ** -- Combining the abundance.tsv in one file --**
# # NOTE : move only all the abundance.tsv in one folder

cd $KALLISTO_DIR
for fn in *_abundance.tsv;
do 
      samplename="${fn%_abundance.tsv}"
      echo "Processing sample ${samplename}"
      head "$samplename"_abundance.tsv
      #problem: retained co-ordinates, which does not input well into SQANTI2
      # solution: retain the PB.ID
      while read line ; do
            first=$( echo "$line" |cut -d\| -f1 ) # each read line, and remove the first part i.e. PacBio ID
            rest=$( echo "$line" | cut -d$'\t' -f2-5 ) #save the remaining columns
            echo $first $rest # concatenate
      done < "$samplename"_abundance.tsv > "$samplename"_temp_abundance.tsv

      header=$(head -n 1 "$samplename"_abundance.tsv)
    sed -i '1d' "$samplename"_temp_abundance.tsv # remove header of temp.file to be replaced
        echo $header > foo
    cat foo "$samplename"_temp_abundance.tsv > "$samplename"_mod_abundance.tsv
        echo "Kallisto "$samplename"_mod_abundance.tsv"
        head "$samplename"_mod_abundance.tsv
        rm "$samplename"_temp_abundance.tsv
        rm foo

done

# #--Combining all the mod_abundance.tsv
python kallisto.py -i $KALLISTO_DIR/<path/to/_mod_abundance>

