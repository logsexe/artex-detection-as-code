# ARTEX detection-as-code — Sigma -> SPL + KQL, pipelines applied.
#
#   make image   build the pinned sigma-cli toolchain image (once)
#   make build   compile the whole Sigma tree -> build/spl, build/kql, build/unsupported.txt
#   make demo    print one rule's SPL and KQL side by side (pipelines applied)
#   make clean   remove build artifacts
#
# Runs the pinned toolchain in a container; the only host dependency is Docker.
# Paths are absolute host paths so this works whether you run it by hand on the
# host or from CI.

IMAGE     := artex-dac:local
CURDIR    := $(shell pwd)
SIGMA_DIR := $(abspath $(CURDIR)/../detections/sigma)
DEMO_RULE ?= destructive_command_hunting

RUN = docker run --rm \
	-v $(SIGMA_DIR):/sigma:ro \
	-v $(CURDIR):/work \
	--entrypoint sh $(IMAGE)

.PHONY: image build demo clean

image:
	docker build -t $(IMAGE) $(CURDIR)

build: image
	docker run --rm \
	  -v $(SIGMA_DIR):/sigma:ro \
	  -v $(CURDIR):/work \
	  $(IMAGE)

# One rule, both targets, side by side — proof the house pipelines are applied.
demo: image
	@$(RUN) -c '\
	  echo "===================== SIGMA SOURCE ($(DEMO_RULE)) =====================";\
	  sed -n "1,120p" /sigma/$(DEMO_RULE).yml;\
	  echo;\
	  echo "===================== SPLUNK SPL  (-t splunk -p splunk_windows -p house) =====================";\
	  sigma convert -t splunk -p splunk_windows -p /work/pipelines/splunk_artex_house.yml /sigma/$(DEMO_RULE).yml;\
	  echo;\
	  echo "===================== SENTINEL KQL (-t kusto -p house -p sentinel_asim) =====================";\
	  sigma convert -t kusto -p /work/pipelines/sentinel_asim_artex_house.yml -p sentinel_asim /sigma/$(DEMO_RULE).yml'

clean:
	rm -rf $(CURDIR)/build
