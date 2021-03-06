#!/usr/bin/make -rRsf

###########################################
###        -usage 'assembly.mk READ1=/location/of/read1.fastq READ2=/location/of/read2.fastq'
###			Full usage guidelines in README	         
###
###
###         -Make sure your BWA and Trinity are installed and in 
###          your path
###        
###          
############################################


##### No Editing should be necessary below this line  #####

MINLEN=25
PHRED=33
SEQ=fq
MINK=1
MEM=2
TRIM=2
CPU=2
BCPU=$(CPU)
RUN=run
READ1=left.fastq
READ2=right.fastq
BCODES=barcodes.fa



TRINITY ?= $(shell which 'Trinity.pl')
MAKEDIR := $(dir $(firstword $(MAKEFILE_LIST)))


.PHONY: check clean
all: check $(RUN)_left.$(TRIM).fastq $(RUN)_right.$(TRIM).fastq $(RUN).Trinity.fasta $(RUN).xprs
trim: check $(RUN)_left.$(TRIM).fastq $(RUN)_right.$(TRIM).fastq
assemble: check $(RUN).Trinity.fasta
express: check $(RUN).xprs
single: check $(RUN)_SE.$(TRIM).fastq $(RUN).SE.Trinity.fasta $(RUN).SE.xprs
flash: check $(RUN)_left.FL.fastq $(RUN)_right.FL.fastq $(RUN)_left.FL$(TRIM).fastq $(RUN)_right.FL$(TRIM).fastq $(RUN).FLASH.Trinity.fasta $(RUN).FLASH.xprs


check:
	@echo "\n\n\n"###I am checking to see if you have all the dependancies installed.### "\n"
	command -v samtools view >/dev/null 2>&1 || { echo >&2 "I require samtools but it's not installed.  Aborting."; exit 1; }
	@echo samtools is Installed
	command -v bwa mem >/dev/null 2>&1 || { echo >&2 "I require BWA but it's not installed.  Aborting."; exit 1; }
	@echo BWA is Installed
	command -v $(TRINITY) >/dev/null 2>&1 || { echo >&2 "I require Trinity but it's not installed.  Aborting."; exit 1; }
	@echo Trinity is Installed
	if [ -f $(READ1) ]; then echo 'left fastQ exists'; else echo 'Im having trouble finding your left fastQ file, check PATH \n'; exit 1; fi;
	if [ -f $(READ2) ]; then echo 'right fastQ exists \n'; else echo 'Im having trouble finding your right fastQ file, check PATH \n'; fi;
	chmod -w $(READ1) 2>/dev/null; true
	chmod -w $(READ2) 2>/dev/null; true

$(RUN)_left.$(TRIM).fastq $(RUN)_right.$(TRIM).fastq: $(READ1) $(READ2)
	@echo About to start trimming
		java -XX:ParallelGCThreads=32 -Xmx$(MEM)g -jar ${MAKEDIR}/trimmomatic-0.32.jar PE -phred$(PHRED) -threads $(CPU) \
		$(READ1) \
		$(READ2) \
		$(RUN).pp.1.fq \
		$(RUN).up.1.fq \
		$(RUN).pp.2.fq \
		$(RUN).up.2.fq \
		ILLUMINACLIP:${MAKEDIR}/$(BCODES):2:40:15 \
		LEADING:$(TRIM) TRAILING:$(TRIM) SLIDINGWINDOW:4:$(TRIM) MINLEN:$(MINLEN) 2> trim.log ; 
		cat $(RUN).pp.1.fq $(RUN).up.1.fq > $(RUN)_left.$(TRIM).fastq ; 
		cat $(RUN).pp.2.fq $(RUN).up.2.fq > $(RUN)_right.$(TRIM).fastq ; 
	
$(RUN).Trinity.fasta: $(RUN)_left.$(TRIM).fastq $(RUN)_right.$(TRIM).fastq
	$(TRINITY) --full_cleanup --min_kmer_cov $(MINK) --seqType $(SEQ) --JM $(MEM)G --PasaFly --bflyGCThreads 25 --bflyHeapSpaceMax $(MEM)G --bflyCPU $(BCPU) \
	--left $(RUN)_left.$(TRIM).fastq --right $(RUN)_right.$(TRIM).fastq --group_pairs_distance 999 --CPU $(CPU) --output $(RUN)
	
$(RUN).xprs: $(RUN).Trinity.fasta
		@echo ---Quantitiating Transcripts---
		bwa index -p index $(RUN).Trinity.fasta
		bwa mem -t $(CPU) index $(READ1) $(READ2) 2>bwa.log | samtools view -Sb - > $(RUN).bam
		samtools flagstat $(RUN).bam > $(RUN).map.stats &
		@echo --eXpress---
		${MAKEDIR}/express -o $(RUN).xprs \
		-p $(CPU) $(RUN).Trinity.fasta $(RUN).bam 2>express.log

###SE Support###

$(RUN)_SE.$(TRIM).fastq:$(READ1)
	@echo About to start trimming
		java -XX:ParallelGCThreads=32 -Xmx$(MEM)g -jar ${MAKEDIR}/trimmomatic-0.32.jar SE -phred$(PHRED) -threads $(CPU) \
		$(READ1) \
		$(RUN)_SE.$(TRIM).fastq \
		ILLUMINACLIP:${MAKEDIR}/$(BCODES):2:40:15 \
		LEADING:$(TRIM) TRAILING:$(TRIM) SLIDINGWINDOW:4:$(TRIM) MINLEN:$(MINLEN) 2> trim.log

$(RUN).SE.Trinity.fasta:$(RUN)_SE.$(TRIM).fastq
	$(TRINITY) --full_cleanup --min_kmer_cov $(MINK) --seqType $(SEQ) --JM $(MEM)G --PasaFly --bflyGCThreads 25 --bflyHeapSpaceMax $(MEM)G --bflyCPU $(BCPU) \
	--single $(RUN)_SE.$(TRIM).fastq --CPU $(CPU) --output $(RUN).SE

$(RUN).SE.xprs:$(RUN).SE.Trinity.fasta
		@echo ---Quantitiating Transcripts---
		bwa index -p index $(RUN).SE.Trinity.fasta
		bwa mem -t $(CPU) index $(READ1) 2>bwa.log | samtools view -Sb - > $(RUN).SE.bam
		samtools flagstat $(RUN).SE.bam > $(RUN).map.stats &
		@echo --eXpress---
		${MAKEDIR}/express -o $(RUN).xprs \
		-p $(CPU) $(RUN).SE.Trinity.fasta $(RUN).SE.bam 2>express.log


###FLASH Support###



$(RUN)_left.FL.fastq $(RUN)_right.FL.fastq: $(READ1) $(READ2)
	flash -t $(CPU) -p $(PHRED) $(READ1) $(READ2)
	cat out.notCombined_1.fastq out.extendedFrags.fastq > $(RUN)_left.FL.fastq
	mv out.notCombined_2.fastq $(RUN)_right.FL.fastq




$(RUN)_left.FL$(TRIM).fastq $(RUN)_right.FL$(TRIM).fastq:$(RUN)_left.FL.fastq $(RUN)_right.FL.fastq
	@echo About to start trimming
		java -XX:ParallelGCThreads=32 -Xmx$(MEM)g -jar ${MAKEDIR}/trimmomatic-0.32.jar PE -phred$(PHRED) -threads $(CPU) \
		$(RUN)_left.FL.fastq \
		$(RUN)_right.FL.fastq \
		$(RUN).pp.1.fq \
		$(RUN).up.1.fq \
		$(RUN).pp.2.fq \
		$(RUN).up.2.fq \
		ILLUMINACLIP:${MAKEDIR}/$(BCODES):2:40:15 \
		LEADING:$(TRIM) TRAILING:$(TRIM) SLIDINGWINDOW:4:$(TRIM) MINLEN:$(MINLEN) 2> trim.log ; 
		cat $(RUN).pp.1.fq $(RUN).up.1.fq > $(RUN)_left.FL$(TRIM).fastq ; 
		cat $(RUN).pp.2.fq $(RUN).up.2.fq > $(RUN)_right.FL$(TRIM).fastq ; 


$(RUN).FLASH.Trinity.fasta: $(RUN)_left.FL$(TRIM).fastq $(RUN)_right.FL$(TRIM).fastq
	$(TRINITY) --full_cleanup --min_kmer_cov $(MINK) --seqType $(SEQ) --JM $(MEM)G --PasaFly --bflyGCThreads 25 --bflyHeapSpaceMax $(MEM)G --bflyCPU $(BCPU) \
	--left $(RUN)_left.FL$(TRIM).fastq --right $(RUN)_right.FL$(TRIM).fastq --group_pairs_distance 999 --CPU $(CPU) --output $(RUN).FLASH
	
$(RUN).FLASH.xprs:$(RUN).FLASH.Trinity.fasta
		@echo ---Quantitiating Transcripts---
		bwa index -p index $(RUN).FLASH.Trinity.fasta
		bwa mem -t $(CPU) index $(READ1) $(READ2) 2>bwa.log | samtools view -Sb - > $(RUN).FLASH.bam
		samtools flagstat $(RUN).FLASH.bam > $(RUN).map.stats &
		@echo --eXpress---
		${MAKEDIR}/express -o $(RUN).FLASH.xprs \
		-p $(CPU) $(RUN).FLASH.Trinity.fasta $(RUN).FLASH.bam 2>express.log


nuclear: 
	rm out* index* run.map.stats run.bam *log 2>/dev/null; true
	rm -fr $(RUN)* 2>/dev/null; true