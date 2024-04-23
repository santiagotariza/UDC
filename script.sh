#!/bin/bash

#SBATCH -t 24:00:00 # execution time
#SBATCH -N 1
#SBATCH -n 64
#SBATCH --mem=128GB
#SBATCH --mail-type=all
#SBATCH --mail-user=santiago.ariza@udc.es

# Locales config to avoid output warnings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Module loading code
module load cesga/2020 fastqc/0.12.1 trimmomatic/0.39 gcccore/system hisat2/2.2.1 samtools/1.9 subread/2.0.5

# Filenames
filename1="SRR28407037"
filename2="SRR28407042"
filename3="SRR28407041"

# Alternative code for user asked filenames (requires prompt interaction)
#read -p "Enter filename 3: " filename3

# Clean the previous log file
rm times.txt

# Pipeline runtime
run_pipeline() {
    local threads="$1"
    local filename="$2"
    
    # Worktitle
    echo "--Working with $filename and $threads threads...--"

    # Timer start
    SECONDS=0
    
    # STEP 1: Run fastqc
    local start_fastqc=$SECONDS
    fastqc "data/$filename.fastq" -o data/
    local end_fastqc=$SECONDS
    local fastqc_duration=$((end_fastqc - start_fastqc))
    echo "fastqc took $fastqc_duration seconds"
    echo" "

    # STEP 2: Run trimmomatic to trim reads with poor quality
    local start_trimmomatic=$SECONDS
    java -jar /opt/cesga/2020/software/Core/trimmomatic/0.39/trimmomatic-0.39.jar SE -threads "$threads" "data/$filename.fastq" "data/${filename}_trimmed.fastq" TRAILING:10 -phred33
    local end_trimmomatic=$SECONDS
    local trimmomatic_duration=$((end_trimmomatic - start_trimmomatic))
    echo "Trimmomatic took $trimmomatic_duration seconds"
    echo " "

    # STEP 3: Run 2nd fastqc on trimmed data
    local start_sndfastqc=$SECONDS
    fastqc "data/$filename_trimmed.fastq" -o data/
    local end_sndfastqc=$SECONDS
    local sndfastqc_duration=$((end_sndfastqc - start_sndfastqc))
    echo "fastqc took $sndfastqc_duration seconds"
    echo " "

    # STEP 4: Run alignment
    local start_hisat2=$SECONDS
    hisat2 -q --rna-strandness R -p "$threads" -x HISAT2/grch38/genome -U "data/$filename_trimmed.fastq" | samtools sort -@ "$threads" -o "HISAT2/$filename_trimmed.bam"
    local end_hisat2=$SECONDS
    local hisat2_duration=$((end_hisat2 - start_hisat2))
    echo "HISAT2 took $hisat2_duration seconds"
    echo " "

    # STEP 5: Run featureCounts
    local start_featureCounts=$SECONDS
    featureCounts -T "$threads" -a data/hg38/Homo_sapiens.GRCh38.106.gtf -o "quants/$filename_featurecounts.txt" "HISAT2/$filename_trimmed.bam"
    local end_featureCounts=$SECONDS
    local featureCounts_duration=$((end_featureCounts - start_featureCounts))
    echo "featureCounts took $featureCounts_duration seconds"
    echo " "

    # STEP 6: Returns the total amount of time for the specified thread and file
    total_duration=$SECONDS
    echo "Total time elapsed: $(($total_duration / 60)) minutes and $(($total_duration % 60)) seconds for $filename with $threads threads."
    echo "------------------"
    echo " "
    echo " "
}

# Execute the pipeline for the specified number of threads and files
for filename in "$filename1" "$filename2" "$filename3"; do
    for threads in 1 2 4 8 16 32 64; do
        run_pipeline "$threads" "$filename" >> times.txt
    done
done