CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
UI_IMAGE = quay.io/ztpfw/ui
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}" | tr '[:upper:]' '[:lower:]' | tr '\/' '-')
HASH := $(shell git rev-parse HEAD)
RELEASE ?= latest
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(RELEASE)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(RELEASE)
EDGECLUSTERS_FILE ?= ${PWD}/hack/deploy-hub-local/edgeclusters.yaml
PULL_SECRET ?= ${HOME}/openshift_pull.json
OCP_VERSION ?= 4.10.13
ACM_VERSION ?= 2.4
ODF_VERSION ?= 4.9

.PHONY: all-images pipe-image pipe-image-ci ui-image ui-image-ci all-hub-sno all-hub-compact all-edgecluster-sno all-edgecluster-compact build-pipe-image build-ui-image push-pipe-image push-ui-image doc build-hub-sno build-hub-compact wait-for-hub-sno deploy-pipe-hub-sno deploy-pipe-hub-compact build-edgecluster-sno build-edgecluster-compact deploy-pipe-edgecluster-sno deploy-pipe-edgecluster-compact bootstrap bootstrap-ci deploy-pipe-hub-ci deploy-pipe-hub-ci deploy-pipe-edgecluster-sno-ci deploy-pipe-edgecluster-compact-ci all-hub-sno-ci all-hub-compact-ci all-edgecluster-sno-ci all-edgecluster-compact-ci all-images-ci
.EXPORT_ALL_VARIABLES:

all-images: pipe-image ui-image
all-images-ci: pipe-image-ci ui-image-ci

pipe-image: build-pipe-image push-pipe-image
ui-image: build-ui-image push-ui-image

pipe-image-ci: build-pipe-image-ci push-pipe-image-ci
ui-image-ci: build-ui-image-ci push-ui-image-ci

all-hub-sno: build-hub-sno bootstrap wait-for-hub-sno deploy-pipe-hub-sno
all-hub-compact: build-hub-compact bootstrap deploy-pipe-hub-compact
all-edgecluster-sno: build-edgecluster-sno bootstrap deploy-pipe-edgecluster-sno
all-edgecluster-compact: build-edgecluster-compact bootstrap deploy-pipe-edgecluster-compact

all-hub-sno-ci: build-hub-sno bootstrap-ci deploy-pipe-hub-ci
all-hub-compact-ci: build-hub-compact bootstrap-ci deploy-pipe-hub-ci
all-edgecluster-sno-ci: build-edgecluster-sno bootstrap-ci deploy-pipe-edgecluster-sno-ci
all-edgecluster-compact-ci: build-edgecluster-compact bootstrap-ci deploy-pipe-edgecluster-compact-ci

### Manual builds
build-pipe-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

push-pipe-image: build-pipe-image
	podman push $(FULL_PIPE_IMAGE_TAG)

push-ui-image: build-ui-image
	podman push $(FULL_UI_IMAGE_TAG)

### CI
build-pipe-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(PIPE_IMAGE):$(RELEASE) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(UI_IMAGE):$(RELEASE) -f $(CI_FOLDER)/Containerfile.UI .

push-pipe-image-ci: build-pipe-image-ci
	podman push $(PIPE_IMAGE):$(RELEASE)

push-ui-image-ci: build-ui-image-ci
	podman push $(UI_IMAGE):$(RELEASE)

doc:
	bash build.sh

build-hub-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-hub-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

build-edgecluster-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-edgecluster-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

wait-for-hub-sno:
	${PWD}/shared-utils/wait_for_sno_mco.sh &

deploy-pipe-hub-sno:
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-hub-compact:
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-sno:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters-sno && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-compact:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-hub-ci:
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-sno-ci:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters-sno && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-compact-ci:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters && \
	tkn pr logs -L -n edgecluster-deployer -f

bootstrap:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(BRANCH)

bootstrap-ci:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(RELEASE)

clean:
	oc delete managedcluster $(EDGE_NAME); \
	oc delete ns $(EDGE_NAME); \
	oc rollout restart -n openshift-machine-api deployment/metal3; \
	kcli delete vm $(EDGE_NAME)-m0 $(EDGE_NAME)-m1 $(EDGE_NAME)-m2 $(EDGE_NAME)-w0
