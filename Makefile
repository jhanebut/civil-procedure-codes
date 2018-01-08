OCR_OUTPUTS := $(patsubst pdf/%.pdf, procedure-codes/%.txt, $(wildcard pdf/*.pdf))
CLEAN_CODES := $(patsubst procedure-codes/%.txt, cleaned-codes/%.txt, $(wildcard procedure-codes/*.txt))
SPLIT_CODES := $(patsubst cleaned-codes/%.txt, procedure-code-sections/%-SPLIT.txt, $(wildcard legal-codes/*.txt))
INCLUDES  := $(wildcard www-lib/*.html)

all : cache/corpus-lsh.rda cache/network-graphs.rda article/Funk-Mullen.Spine-of-Legal-Practice.pdf index.html clusters

# Clean up the codes in `procedure-codes/`
.PHONY : codes
codes : $(CLEAN_CODES)

cleaned-codes/%.txt : procedure-codes/%.txt
	Rscript --vanilla scripts/clean-text.R $^ $@

# Split the codes into sections
.PHONY : splits
splits : $(SPLIT_CODES)

procedure-code-sections/%-SPLIT.txt : cleaned-codes/%.txt
	@mkdir -p procedure-code-sections
	Rscript --vanilla scripts/split-code.R $<
	@touch $@

# Find the similarities in the split codes
.PHONY : lsh
lsh : cache/corpus-lsh.rda

cache/corpus-lsh.rda : $(SPLIT_CODES)
	Rscript --vanilla scripts/corpus-lsh.R

# Create the network graph data from the split codes
.PHONY : network
network : cache/network-graphs.rda

cache/network-graphs.rda : cache/corpus-lsh.rda
	Rscript --vanilla scripts/network-graphs.R

# Create the clusters
.PHONY : clusters
clusters : out/clusters/DONE.txt

out/clusters/DONE.txt : cache/corpus-lsh.rda
	mkdir -p out/clusters
	Rscript --vanilla scripts/cluster-sections.R && \
	touch $@

# Create the article
.PHONY : article
article : article/Funk-Mullen.Spine-of-Legal-Practice.pdf

article/Funk-Mullen.Spine-of-Legal-Practice.pdf : article/Funk-Mullen.Spine-of-Legal-Practice.Rmd cache/corpus-lsh.rda cache/network-graphs.rda
	R --slave -e "set.seed(100); rmarkdown::render('$<', output_format = 'all')"

# Update certain files in the research compendium for AHR
.PHONY : compendium
compendium :
	zip compendium/all-section-matches.csv.zip out/matches/all_matches.csv
	zip compendium/best-section-matches.csv.zip out/matches/best_matches.csv
	zip -r compendium/procedure-codes.zip procedure-codes/
	zip -r compendium/procedure-code-sections.zip procedure-code-sections/

# Create a listing of the files in the notebook home page
index.html : index.Rmd $(INCLUDES)

.PHONY : clean
clean :
	rm -rf temp/*

.PHONY : clean-splits
clean-splits :
	rm -f cleaned-codes/*
	rm -rf procedure-code-sections

.PHONY : clean-clusters
clean-clusters :
	rm -rf out/clusters
	rm -f cache/clusters.rds

.PHONY : clobber
clobber : clean
	rm -f cache/*
	rm -rf out/*
