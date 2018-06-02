# Lambdar: Build R for Amazon Linux and deploy to AWS Lambda
#
# Usage:
#  make docker   - build AWS Lambda compatible R Docker container
#  make lambdar  - build minimal r-$(R_VERSION).tar.gz for AWS Lambda
#  make test     - quick check that the built R version works
#  make deploy   - deploy to AWS Lambda
#
# The Docker container henrikbengtsson/lambdar:build is defined by
# the docker-lambdar/Dockerfile file.
name=lambdar

R_VERSION=3.3.2

# R must be built on a system compatible with Amazon Linux with glibc <= 2.17.
glibc_version=$(shell ldd --version | head -1 | sed -E 's/.*GLIBC[[:space:]]([0-9.-]+).*/\1/g' | tr - .)
glibc_version_smallest=$(shell printf "$(glibc_version)\n2.17" | sort -V | head -1)
#ifeq ($(glibc_version_smallest), 2.17)
#  $(error "ERROR: R must be built with GLIBC (<= 2.17) in order to work on AWS Lambda: $(glibc_version)")
#endif

.DELETE_ON_ERROR:
.SECONDARY:

all: docker lambdar

lambdar: $(name).zip

docker:
	docker build -t henrikbengtsson/lambdar:build docker-lambdar/

debug:
	@echo "R version: $(R_VERSION)"
	@echo "GLIBC version: $(glibc_version)"

deploy: $(name).zip.json

# Bundle up R and all of its dependencies
r-%.tar.xz: lambdar.mk
	docker run -v $(PWD):/xfer -w /xfer henrikbengtsson/lambdar:build make -f lambdar.mk

#r-%.tar.xz: r-%.tar
#	xz -9 $<

test: r-$(R_VERSION).tar.xz
	docker run -it --env INTERACTIVE=true --env R_VERSION=$(R_VERSION) -v $(PWD):/xfer -w /xfer henrikbengtsson/lambdar:build bash -C test-r.sh

# Build the zip archive for AWS Lambda
%.zip: %.js r-$(R_VERSION).tar.xz
	zip -q9r $@ $^

# Deploy the zip to Lambda
%.zip.json: %.zip
	aws lambda update-function-code --function-name $* --zip-file fileb://$< > $@

clean:
	@rm -f r-$(R_VERSION).tar
	@rm -f $(name).zip
