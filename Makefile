## ------------------------------------------------------------------------------------ ##
## Preparation - set software paths
## ------------------------------------------------------------------------------------ ##
## Path to R binary and library, including arguments to R CMD BATCH
## Ex: R := R_LIBS=/home/Shared/Rlib/release-3.5-lib/ /usr/local/R/R-3.4.0/bin/R CMD BATCH --no-restore --no-save
## Ex: R := R CMD BATCH
R := 

## Path to Salmon binary
## Ex: salmon := /home/charlotte/software/Salmon-0.8.2_linux_x86_64/bin/salmon
salmon := 

## Path to TrimGalore! and cutadapt
## Ex: trimgalore := /home/charlotte/software/trim_galore_v0.4.4/trim_galore
## Ex: cutadapt := /home/charlotte/.local/bin/cutadapt
trimgalore := 
cutadapt := 

## Path to STAR
## Ex: STAR := /home/Shared_penticton/software/STAR/source/STAR
STAR := 

## Path to samtools binary
## Ex: samtools := /usr/local/bin/samtools
samtools := 

## Path to MultiQC 
## Ex: multiqc := multiqc
multiqc := 

## Path to bedtools and the bedGraphToBigWig script
## Ex: bedtools := /usr/local/bin/bedtools
## Ex: bedGraphToBigWig := bedGraphToBigWig
bedtools := 
bedGraphToBigWig :=

## ------------------------------------------------------------------------------------ ##
## Preparation - set paths to reference files
## ------------------------------------------------------------------------------------ ##
## Path to existing genome fasta file
## Ex: genome := reference/genome/Danio_rerio.GRCz10.dna.toplevel.fa
genome := 

## Path to existing gtf file matching the genome fasta
## Ex: gtf := reference/gtf/Danio_rerio.GRCz10.87.gtf
gtf := 

## Path to STAR genome index. Will be generated from the genome fasta file if it doesn't exist
## Ex: STARindex := reference/STARIndex/Danio_rerio.GRCz10.dna.toplevel
STARindex := 

## Path to existing cDNA and ncRNA fasta files
## Ex: cdna := reference/cDNA/Danio_rerio.GRCz10.cdna.all.fa
## Ex: ncrna := reference/ncRNA/Danio_rerio.GRCz10.ncrna.fa
cdna := 
ncrna := 

## Path to merged cDNA and ncRNA fasta file (will be generated by the script)
## Ex: txome := reference/Danio_rerio.GRCz10.cdna.ncrna.fa
txome := 

## Path to Salmon index. Will be generated from the merged cDNA and ncRNA fasta files if it doesn't exist
## Ex: salmonindex := reference/SalmonIndex/Danio_rerio.GRCz10.cdna.ncrna.sidx_0.8.2
salmonindex := 

## Path to rds file where the tx2gene mapping will be stored
## Ex: tx2gene := reference/SalmonIndex/Danio_rerio.GRCz10.cdna.ncrna_tx2gene.rds
tx2gene := 

## Path to text file that will be generated to contain reference chromosome lengths
## Ex: chromlengthtxt := reference/Danio_rerio.GRCz10.chrlengths.txt
chromlengthtxt := 

## ------------------------------------------------------------------------------------ ##
## Preparation - list files to process
## ------------------------------------------------------------------------------------ ##
## List sample IDs (should correspond to the FASTQ file names (excluding {_R1/2}.fastq.gz). 
## Usually only one of PEsamples or SEsamples is non-empty.
## Ex: SEsamples := S1 S2 S3
PEsamples := 
SEsamples := 
samples := PEsamples SEsamples

## Provide read length. This affects the generation of the STAR index
## Ex: readlength := 126
readlength := 

## Path to metadata text file. This file must have at least one column, named "ID", 
## containing the same values as the "samples" variable above.
## Ex: metatxt := metadata/metadata.txt 
metatxt :=

.PHONY: all

## ------------------------------------------------------------------------------------ ##
## Target definition
## ------------------------------------------------------------------------------------ ##
## Run all analyses
all: MultiQC/multiqc_report.html

## List all the packages that were used by the R analyses
listpackages:
	$(R) scripts/list_packages.R Rout/list_packages.Rout

## ------------------------------------------------------------------------------------ ##
## Reference preparation
## ------------------------------------------------------------------------------------ ##
## Merge cDNA and ncRNA fasta files
$(txome): $(cdna) $(ncrna)
	mkdir -p $(@D)
	cat $(cdna) $(ncrna) > $@

## Salmon - generate index from merged cDNA and ncRNA files
$(salmonindex)/hash.bin: $(txome)
	mkdir -p $(@D)
	$(salmon) index -t $< -k 31 -i $(@D) --type quasi

## Generate tx2gene mapping
$(tx2gene): $(txome)
	mkdir -p $(@D)
	mkdir -p Rout
	$(R) "--args transcriptfasta='$(txome)' outrds='$@'" scripts/generate_tx2gene.R Rout/generate_tx2gene.Rout

## Generate STAR index
$(STARindex)/SA: $(genome) $(gtf)
	mkdir -p $(@D)
	$(STAR) --runMode genomeGenerate --runThreadN 20 --genomeDir $(STARindex) \
	--genomeFastaFiles $(genome) --sjdbGTFfile $(gtf) --sjdbOverhang $(readlength)

## ------------------------------------------------------------------------------------ ##
## Quality control
## ------------------------------------------------------------------------------------ ##
## FastQC, original reads
define fastqcrule
FastQC/$(1)_fastqc.zip: FASTQ/$(1).fastq.gz
	mkdir -p $$(@D)
	fastqc -o $$(@D) -t 10 $$<
endef
$(foreach S,$(PEsamples),$(eval $(call fastqcrule,$(S)_R1)))
$(foreach S,$(PEsamples),$(eval $(call fastqcrule,$(S)_R2)))
$(foreach S,$(SEsamples),$(eval $(call fastqcrule,$(S))))

## FastQC, trimmed reads
define fastqcrule2
FASTQC/$(1)_fastqc.zip: FASTQtrimmed/$(1).fq.gz
	mkdir -p $$(@D)
	fastqc -o $$(@D) -t 10 $$<
endef
$(foreach S,$(PEsamples),$(eval $(call fastqcrule2,$(S)_R1_val_1)))
$(foreach S,$(PEsamples),$(eval $(call fastqcrule2,$(S)_R2_val_2)))
$(foreach S,$(SEsamples),$(eval $(call fastqcrule2,$(S)_val)))

MultiQC/multiqc_report.html: \
$(foreach S,$(PEsamples),FastQC/$(S)_R1_fastqc.zip) \
$(foreach S,$(PEsamples),FastQC/$(S)_R2_fastqc.zip) \
$(foreach S,$(SEsamples),FastQC/$(S)_fastqc.zip) \
$(foreach S,$(PEsamples),FastQC/$(S)_R1_val_1_fastqc.zip) \
$(foreach S,$(PEsamples),FastQC/$(S)_R2_val_2_fastqc.zip) \
$(foreach S,$(SEsamples),FastQC/$(S)_val_fastqc.zip) \
$(foreach S,$(PEsamples),FASTQtrimmed/$(S)_R1_val_1.fq.gz) \
$(foreach S,$(PEsamples),FASTQtrimmed/$(S)_R2_val_2.fq.gz) \
$(foreach S,$(SEsamples),FASTQtrimmed/$(S)_val.fq.gz)
	mkdir -p $(@D)
	$(multiqc) FastQC FASTQtrimmed -f -o $(@D)

## ------------------------------------------------------------------------------------ ##
## Adapter trimming
## ------------------------------------------------------------------------------------ ##
## TrimGalore!
define PEtrimrule
FASTQtrimmed/$(1)_R1_val_1.fq.gz: FASTQ/$(1)_R1.fastq.gz FASTQ/$(1)_R2.fastq.gz
	mkdir -p $$(@D)
	$(trimgalore) -q 20 --phred33 --length 20 -o $$(@D) --path_to_cutadapt $(cutadapt) \
	--paired $$(word 1,$$^) $$(word 2,$$^) 
endef
$(foreach S,$(PEsamples),$(eval $(call PEtrimrule,$(S))))

define PEtrimrule2
FASTQtrimmed/$(1)_R2_val_2.fq.gz: FASTQtrimmed/$(1)_R1_val_1.fq.gz
endef
$(foreach S,$(PEsamples),$(eval $(call PEtrimrule2,$(S))))

define SEtrimrule
FASTQtrimmed/$(1)_val.fq.gz: FASTQ/$(1).fastq.gz
	mkdir -p $$(@D)
	$(trimgalore) -q 20 --phred33 --length 20 -o $$(@D) --path_to_cutadapt $(cutadapt) \
	$$(word 1,$$^)
endef
$(foreach S,$(SEsamples),$(eval $(call SEtrimrule,$(S))))

## ------------------------------------------------------------------------------------ ##
## Salmon abundance estimation
## ------------------------------------------------------------------------------------ ##
## Estimate abundances with Salmon
define PEsalmonrule
salmon/$(1)/quant.sf: $(salmonindex)/hash.bin \
FASTQtrimmed/$(1)_R1_val_1.fq.gz FASTQtrimmed/$(1)_R2_val_2.fq.gz
	mkdir -p $$(@D)
	$(salmon) quant -i $$(word 1,$$(^D)) -l A -1 $$(word 2,$$^) -2 $$(word 3,$$^) \
	-o $$(@D) --gcBias --seqBias -p 10
endef
$(foreach S,$(PEsamples),$(eval $(call PEsalmonrule,$(S))))

define SEsalmonrule
salmon/$(1)/quant.sf: $(salmonindex)/hash.bin FASTQtrimmed/$(1)_val.fq.gz
	mkdir -p $$(@D)
	$(salmon) quant -i $$(word 1,$$(^D)) -l A -r $$(word 2,$$^) \
	-o $$(@D) --seqBias -p 10
endef
$(foreach S,$(SEsamples),$(eval $(call SEsalmonrule,$(S))))

## ------------------------------------------------------------------------------------ ##
## STAR mapping
## ------------------------------------------------------------------------------------ ##
## Genome mapping with STAR
define PEstarrule
STAR/$(1)/$(1)_Aligned.sortedByCoord.out.bam: $(STARindex)/SA \
FASTQtrimmed/$(1)_R1_val_1.fq.gz FASTQtrimmed/$(1)_R2_val_2.fq.gz
	mkdir -p $$(@D)
	$(STAR) --genomeDir $(STARindex) \
	--readFilesIn $$(word 2,$$^) $$(word 3,$$^) \
	--runThreadN 20 --outFileNamePrefix $$(@D)/$(1)_ \
	--outSAMtype BAM SortedByCoordinate --readFilesCommand gunzip -c
endef
$(foreach S,$(PEsamples),$(eval $(call PEstarrule,$(S))))

define SEstarrule
STAR/$(1)/$(1)_Aligned.sortedByCoord.out.bam: $(STARindex)/SA \
FASTQtrimmed/$(1)_val.fq.gz
	mkdir -p $$(@D)
	$(STAR) --genomeDir $(STARindex) \
	--readFilesIn $$(word 2,$$^) \
	--runThreadN 20 --outFileNamePrefix $$(@D)/$(1)_ \
	--outSAMtype BAM SortedByCoordinate --readFilesCommand gunzip -c
endef
$(foreach S,$(SEsamples),$(eval $(call SEstarrule,$(S))))

## Index bam files
define starindexrule
STAR/$(1)/$(1)_Aligned.sortedByCoord.out.bam.bai: STAR/$(1)/$(1)_Aligned.sortedByCoord.out.bam
	$(samtools) index $$<
endef
$(foreach S,$(samples),$(eval $(call starindexrule,$(S))))

## Get chromosome lengths
$(chromlengthtxt): STAR/$(word 1,$(samples))/$(word 1,$(samples))_Aligned.sortedByCoord.out.bam
	$(samtools) view -H $< | grep '@SQ' | cut -f2,3 | sed -e 's/SN://' | sed -e 's/LN://' > $@

## Convert BAM files to bigWig
define bigwigrule
STARbigwig/$(1)_Aligned.sortedByCoord.out.bw: $(chromlengthtxt) STAR/$(1)/$(1)_Aligned.sortedByCoord.out.bam
	mkdir -p $$(@D)	
	$(bedtools) genomecov -split -ibam $$(word 2,$$^) -bg > $$(@D)/$(1)_Aligned.sortedByCoord.out.bedGraph
	$(bedGraphToBigWig) $$(@D)/$(1)_Aligned.sortedByCoord.out.bedGraph $$(word 1,$$^) $$@
	rm -f $$(@D)/$(1)_Aligned.sortedByCoord.out.bedGraph
endef
$(foreach S,$(samples),$(eval $(call bigwigrule,$(S))))

## ------------------------------------------------------------------------------------ ##
## Differential expression
## ------------------------------------------------------------------------------------ ##
## edgeR
output/edgeR_dge.rds: $(tx2gene) $(metatxt) scripts/run_dge_edgeR.R \
$(foreach S,$(samples),salmon/$(S)/quant.sf) 
	mkdir -p output
	mkdir -p Rout
	$(R) "--args tx2gene='$<' salmondir='salmon' outrds='$@' metafile='$(metatxt)'" scripts/run_dge_edgeR.R Rout/run_dge_edgeR.Rout

## ------------------------------------------------------------------------------------ ##
## Shiny app
## ------------------------------------------------------------------------------------ ##
output/shiny_results.rds: output/edgeR_dge.rds $(gtf) $(tx2gene) $(metatxt) \
scripts/prepare_results_for_shiny.R \
$(foreach S,$(samples),STARbigwig/$(S)_Aligned.sortedByCoord.out.bw)
	mkdir -p output
	mkdir -p Rout
	$(R) "--args edgerres='output/edgeR_dge.rds' gtffile='$(gtf)' tx2gene='$(tx2gene)' metafile='$(metatxt)' bigwigdir='STARbigwig' outrds='$@'" scripts/prepare_results_for_shiny.R Rout/prepare_results_for_shiny.Rout






