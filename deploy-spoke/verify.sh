#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

function check_bmhs() {
    cluster=${1}
    wait_time=${2}
    spokenumber=${3}
    timeout=0
    ready=false
    NUM_M=$(yq e ".spokes[${spokenumber}].[]|keys" ${SPOKES_FILE} | grep master | wc -l | xargs)
    NUM_M_MAX=$((NUM_M + 1))

    while [ "${timeout}" -lt "${wait_time}" ]; do
        RCBMH=$(oc --kubeconfig=${KUBECONFIG_HUB} get bmh -n ${cluster} -o jsonpath='{.items[*].status.provisioning.state}')
        # Check state
        if [[ $(echo ${RCBMH} | grep provisioned | wc -w) -eq ${NUM_M} || $(echo ${RCBMH} | grep provisioned | wc -w) -eq ${NUM_M_MAX} ]]; then
            ready=true
            break
        fi
        echo ">> Waiting for BMH on spoke for each cluster node: $(oc get bmh -n ${cluster} -o jsonpath='{.items[*].status.provisioning.state}')"
        echo 'Desired State: provisioned'
        echo

        timeout=$((timeout + 30))
        sleep 30
    done

    if [ "${ready}" == "false" ]; then
        echo "timeout waiting for BMH to be provisioned"
        exit 1
    else
        echo "BMH's for ${cluster} verified"
    fi
}

wait_time=${1}

if [[ $# -lt 1 ]]; then
    echo "Usage :"
    echo "  $0 <Wait Time>"
    exit 1
fi

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

index=0
for SPOKE in ${ALLSPOKES}; do
    echo ">>>> Starting the validation until finish the installation"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    check_bmhs "${SPOKE}" "${wait_time}" ${index}
    check_resource "aci" "${SPOKE}" "Completed" "${SPOKE}" "${SPOKE_KUBECONFIG}"
    index=$((index + 1))
    echo ">>>>EOF"
    echo ">>>>>>>"
done
exit 0
