# ============== 1.	Collecting Seq-HD files =================

Input Files: 
•	96 HD bulls (NOAN, Ref_Reg_Num, Name, BirthDate, Test_ID):
VCF file: HDTom20260121_5_VCF9_20260121.vcf.gz 
Excel file: BullsHD_all_info_2026.xlsx (sheet = ‘bulls_96new’)

•	722 HD bulls (NOAN, Ref_Reg_Num, Name, BirthDate, Test_ID)
VCF file: BullsHD5_5_VCF9_20230414.vcf.gz
Excel file: BullsHD_all_info_2026.xlsx (sheet = ‘HD’) 

•	8 HD bulls (NOAN, Ref_Reg_Num, Name, BirthDate, Test_ID)
 VCF file: BullsHD_Extra8_5_VCF9_20230504.vcf.gz                                                      
 Excel file: ArrayID_8Extra_HD_Bulls.xlsx

# ============== 2.	Merge the 3 HD VCF files ================== 
1. BBB230_merge.sh :
1a.	Re-compressing standard gzip files to bgzip                                                                               
Input: HDTom20260121_5_VCF9_20260121.vcf.gz
       BullsHD5_5_VCF9_20230414.vcf.gz
       BullsHD_Extra8_5_VCF9_20230504.vcf.gz

Output: BullsHDTom_bgzip.vcf.gz                                                                                                                                              	BullsHD5_5_bgzip.vcf.gz                                                                    
 	BullsHD_Extra8_bgzip.vcf.gz

1b.	Filtering VCFs to keep only standard cattle chromosomes (1-29, X)
Input: BullsHDTom_bgzip.vcf.gz                                                                                                                 	BullsHD5_5_bgzip.vcf.gz                                                  
       BullsHD_Extra8_bgzip.vcf.gz

Output: BullsHDTom_filtered.vcf.gz                         
        BullsHD5_5_filtered.vcf.gz
        BullsHD_Extra8_filtered.vcf.gz


1c.	Indexing filtered VCF files
Input: BullsHDTom_filtered.vcf.gz                                                                                                            	BullsHD5_5_filtered.vcf.gz
	BullsHD_Extra8_filtered.vcf.gz

1d.	Check whether the exact same set of variants is present across all three filtered VCF files

Input: BullsHDTom_filtered.vcf.gz                           
       BullsHD5_5_filtered.vcf.gz
       BullsHD_Extra8_filtered.vcf.gz
         	
Output: vcf_diff_output/sites.txt:
# 110: Present in File 1 & File 2, missing in File 3
# 101: Present in File 1 & File 3, missing in File 2
# 011: Present in File 2 & File 3, missing in File 1
# 100, 010, 001: Unique to only one file

1e.	Merge the 3 filtered VCF files with bcftools merge

Input: BullsHDTom_filtered.vcf.gz              
       BullsHD5_5_filtered.vcf.gz
       BullsHD_Extra8_filtered.vcf.gz

Output: HD_merged_output.vcf.gz (825 bulls)

1f.	Indexing merged output VCF
Input: HD_merged_output.vcf.gz

1g.	Extracting Sample IDs to reference the NOANs in the 3 Excel files 
Input: HD_merged_output.vcf.gz

Output: unique_TestIDs.txt (825 unique Test_IDs)
 BBB_HD_825.xlsx

2. BBB825_HD_MENDEL_QC.sh:
2a.	Convert Merged VCF to PLINK 2 Binary Format 
Input: HD_merged_output.vcf.gz (825 bulls)

Output: HD_raw(.bed, .fam, .bim)

2b.	Apply QC Filters (from gualdron_GSE2023):
•	Individual Genotyping Rate >= 95% (--mind 0.05)
•	Marker Call Rate >= 95% (--geno 0.05)
•	Minor Allele Frequency >= 0.5% (--maf 0.005)
•	Hardy-Weinberg Equilibrium p >= 0.001 (--hwe 0.001)

Input: HD_raw (.bed, .fam, .bim)                                                                                        
Output: HD_qc_mind95 (.bed, .fam, .bim)

2c.	Harmonize Family IDs for PLINK 1.9 Mendelian Analysis using pedigree file for the 825 HD bulls
Input: HD_qc_mind95 (.bed, .fam, .bim), pedi_noan825.txt (NOAN, SIRE_NOAN, DAM_NOAN)                                                       
Output: HD_qc_mind95 (updated) (.bed, .fam, .bim) 
FID(1) IID(NOAN) Sire Dam Sex(1) Phenotype(-9)

2d.	Run Mendelian Error Analysis

 -- mendel (mendel alone requires genotyped trios)
 --mendel -duos [only offspring and sire (some offspring NOANs are also Sire_NOANs) are genotyped in the pedigree file, not the dam]

Input: HD_qc_mind95 (updated) (.bed, .fam, .bim)
Output: HD_mendel_report_mind95 (.bed, .fam, .bim)

.mendel: FID(1) + KID (offspring NOAN) + CHR + SNP + CODE + ERROR (exact mendelian error (e.g. C/C x */* -> T/T))
.imendel: FID(1) + IID (offspring NOAN) + N (No of mendelian errors), 
.fmendel(sire): FID(1) + Sire_NOAN + N (No of mendelian errors for the Sire (but one sire can have many offsprings) + CHILD (how many offsprings sire has)
.lmendel: (CHR + SNP + N (No of mendelian errors for current marker))
.hh: FID(1) + NOAN + SNP (which marker applies to each IID(NOAN))


2e.	Convert PLINK binary to VCF and compress it with bgzip for passing to Beagle

Input: HD_qc_mind95 (updated) (.bed, .fam, .bim)
Output: HD_qc_mind95_clean.vcf.gz

#============= 3. Processing data for Beagle phasing ==================#

The point is to pass the filtered HD_qc_mind95_clean.vcf.gz to Beagle 4.1 (before running plink --mendel duos) so that we can observe if Beagle provides better results (less mendelian inconsistencies). After the Beagle imputation, we pass the output file to plink --mendel duos to see if Beagle 4.1 provides less mendelian inconsistencies than the HD. 

1.	BBB825_HD_bcf_index.sh

1a.	Fix VCF header by removing PLINK2's custom chrSet line
Input: HD_qc_mind95_clean.vcf.gz
Output: HD_qc_mind95_clean_fixed.vcf.gz

1b.	Index the fixed cleaned VCF
Input: HD_qc_mind95_clean.vcf.gz

1c.	Count number of variants in cleaned VCF  615312 variants
Input: HD_qc_mind95_clean_fixed.vcf.gz
Output: 615312 variants

1d.	Extracting sorted Sample IDs in the cleaned VCF
Input: HD_qc_mind95_clean_fixed.vcf.gz
Output: cleaned95_Test_IDs.txt (806 Test_IDs)

             
 
2.	run_extrac_chr_825bbb_hd.sh

2a.	Extract SNPs per chromosome(1-29)
 	Input: HD_qc_mind95_clean_fixed.vcf.gz
        Output: cleaned_chr_825bbb_hd_ [1-29].vcf  

3. run_beagleV4.1_allchr_SNP_825_hd.sh 

3a. Correct SNPs genotyping with Beagle 4.1 per chromosome              
Input: cleaned_chr_825bbb_hd_ [1-29].vcf
Output: cleaned_chr_825bbb_hd_corrected_chr[1-29].vcf.gz    

4.	BBB825_HD_bcf_concat   

4a.	Properly compressing and indexing individual chromosome VCFs

Input: cleaned_chr_825bbb_hd_corrected_chr[1-29].vcf.gz
Output: beagle4.1_phased_chr_list.txt 

4b.	Concatenating chromosomes                                           
Input: beagle4.1_phased_chr_list.txt 
Output: 825HD_beagle4.1_phased_genome.vcf.gz    

4c.	Indexing final merged genome VCF
Input: 825HD_beagle4.1_phased_genome.vcf.gz
      
#=================== 4.	Mendelian inconsistencies check ====================
1. run_mendel_plink_BBB825HD.sh
1a.	Convert VCF to PLINK 2 binary format
Input: 825HD_beagle4.1_phased_genome.vcf.gz
Output: 825HD_beagle4.1_phased (,bed, .fam, .bim)

1b.	Restore the pedigree (.fam) using original pedigree mapping file 
Input: 825HD_beagle4.1_phased (,bed, .fam, .bim), pedi_noan825.txt
Output: 825HD_beagle4.1_phased (,bed, .fam, .bim) (updated) 
FID(1) IID(NOAN) Sire Dam Sex(1) Phenotype(-9)

1c.	Run Mendelian Error Analysis(plink - -mendel duos)
Input: 825HD_beagle4.1_phased (,bed, .fam, .bim)
Output: 825HD_mendel_report_beagle4.1_mind95(.mendel, .fmendel, .imendel, .hh)







