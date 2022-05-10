#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

source ${WORKDIR}/shared-utils/common.sh

function wait_for_crd() {
    EDGE_KUBECONFIG=${1}
    EDGE=${2}
    CRD=${3}

    echo ">>>> Waiting for subscription and crd on: ${EDGE}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false

    while [ "$timeout" -lt "1000" ]; do
        echo KUBEEDGE=${EDGE_KUBECONFIG}
        if [[ $(oc --kubeconfig=${EDGE_KUBECONFIG} get crd | grep ${CRD} | wc -l) -eq 1 ]]; then
            ready=true
            break
        fi
        echo "Waiting for CRD ${CRD} to be created"
        sleep 5
        timeout=$((timeout + 5))
    done
    if [ "$ready" == "false" ]; then
        echo timeout waiting for CRD ${CRD}
        exit 1
    fi
}

function get_config() {

    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <EDGECLUSTERS_FILE> <EDGE_NAME> <EDGE_INDEX>"
        exit 1
    fi
    edgeclusters_file=${1}
    edgecluster_name=${2}
    index=${3}

    export CHANGEME_VERSION=$(yq eval ".edgeclusters[${index}].${edgecluster_name}.contrib.gpu-operator.version" ${edgeclusters_file})
}

function deploy_gpu() {
    if ./verify.sh; then

        echo "Installing NFD operator for ${edgecluster}"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-nfd-namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-nfd-operator-group.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-nfd-subscription.yaml
        sleep 2

        wait_for_crd ${EDGE_KUBECONFIG} ${edgecluster} "nodefeaturediscoveries.nfd.openshift.io"

        echo "Installing GPU operator for ${edgecluster}"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-gpu-namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-gpu-operator-group.yaml
        sleep 2
        envsubst <manifests/03-gpu-subscription.yaml | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
        sleep 2

        wait_for_crd ${EDGE_KUBECONFIG} ${edgecluster} "clusterpolicies.nvidia.com"

        echo "Adding GPU node labels with NFD for ${edgecluster}"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/04-nfd-gpu-feature.yaml
        sleep 2

        echo "Adding GPU Cluster Policy for ${edgecluster}"
        envsubst <manifests/05-gpu-cluster-policy.yaml | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
        sleep 2
    else
        echo ">>>> This step is not neccesary, everything looks ready"
    fi

    echo ">>>>EOF"
    echo ">>>>>>>"
}

if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

index=0
for edgecluster in ${ALLEDGECLUSTERS}; do
    extract_kubeconfig_common ${edgecluster}
    get_config ${EDGECLUSTERS_FILE} ${edgecluster} ${index}
    deploy_gpu ${edgecluster}
    index=$((index + 1))
    echo ">> GPU Operator Deployment done in: ${edgecluster}"
done
