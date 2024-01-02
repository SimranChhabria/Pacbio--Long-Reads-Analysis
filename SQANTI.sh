#!/bin/bash
#SBATCH -p bigmem
## number of cores
#SBATCH -n 24
#SBATCH -o sqanti.out

#----
# USAGE: 
# conda activate SQANTI3.env
# export PYTHONPATH=$PYTHONPATH:/rugpfs/fs0/tavz_lab/scratch/schhabria/cDNA_Cupcake/  
# export PYTHONPATH=$PYTHONPATH:/rugpfs/fs0/tavz_lab/scratch/schhabria/cDNA_Cupcake/sequence/
#----


#-----
# Specify paths
#-----

#--- Input files path --#
GENOME_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/ref_files/mouse_ref/GRCm39
ISO_COLLAPSE_DIR=$RESULTS_DIR/iso-seq-collapse
KALLISTO_DIR=$RESULTS_DIR/kallisto_ic
STAR_DIR=$RESULTS_DIR/STAR_BED
SQANTI3_DIR=/rugpfs/fs0/tavz_lab/scratch/schhabria/SQANTI3-5.1.2

#--- Results paths --#
SQANTI3_RES_DIR=$RESULTS_DIR/squanti_qc

#--- Step 7 : Running SQANTI
#------
# Input  : RESULTS-MC/iso-seq-collapse/combined_collapse.gff
#          GRCm39/gencode.vM31.primary_assembly.annotation.gtf
#          GRCm39.primary_assembly.genome.fa
#          Mus_musculus_GRCm38_Ensembl_86.gff3 (download from tappas)
#          $STAR_DIR/*SJ/out.bed
#          $KALLISTO_DIR/kallisto_ic_transcript_count2.tsv    

# Output : classification.txt,
#          junction.txt
#          isoforms.gff
#          isoforms_report.pdf 
#---

 export PYTHONPATH=$PYTHONPATH:/rugpfs/fs0/tavz_lab/scratch/schhabria/cDNA_Cupcake/
 export PYTHONPATH=$PYTHONPATH:/rugpfs/fs0/tavz_lab/scratch/schhabria/cDNA_Cupcake/sequence/

 echo "Processing with gencode.vM31.annotation.gtf for genome annotation "
 python $SQANTI3_DIR/sqanti3_qc.py -t 30 \
       $ISO_COLLAPSE_DIR/combined_collapse.gff $GENOME_DIR/gencode.vM31.primary_assembly.annotation.gtf \
       $GENOME_DIR/GRCm39.primary_assembly.genome.fa \
       -c $STAR_DIR \
       --expression $KALLISTO_DIR/kallisto_ic_transcript_count2.tsv \
       -o sqanti_ng -d $SQANTI3_RES_DIR \
       --isoAnnotLite --report both &> $SQANTI3_RES_DIR/sqanti.qc.log





