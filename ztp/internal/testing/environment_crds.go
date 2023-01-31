/*
Copyright 2023 Red Hat Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
*/

package testing

// This file contains `go:generate` directives to download the CRDs that are used in the testing
// environment.

//go:generate -command get curl --silent --location --output
//go:generate get environment/crds/0010_ingresscontroller.yaml   https://raw.githubusercontent.com/openshift/api/release-4.12/operator/v1/0000_50_ingress-operator_00-ingresscontroller.crd.yaml
//go:generate get environment/crds/0020_agentclusterinstall.yaml https://raw.githubusercontent.com/openshift/assisted-service/v2.14.1/config/crd/bases/extensions.hive.openshift.io_agentclusterinstalls.yaml
//go:generate get environment/crds/0030_clusterdeployment.yaml   https://raw.githubusercontent.com/openshift/hive/master/config/crds/hive.openshift.io_clusterdeployments.yaml
//go:generate get environment/crds/0040_managedcluster.yaml      https://raw.githubusercontent.com/open-cluster-management-io/api/v0.9.0/cluster/v1/0000_00_clusters.open-cluster-management.io_managedclusters.crd.yaml
//go:generate get environment/crds/0050_infraenv.yaml            https://raw.githubusercontent.com/openshift/assisted-service/v2.14.1/config/crd/bases/agent-install.openshift.io_infraenvs.yaml
//go:generate get environment/crds/0060_nmstateconfig.yaml       https://raw.githubusercontent.com/openshift/assisted-service/v2.14.1/config/crd/bases/agent-install.openshift.io_nmstateconfigs.yaml
//go:generate get environment/crds/0070_baremetalhost.yaml       https://raw.githubusercontent.com/metal3-io/baremetal-operator/v0.2.0/config/crd/bases/metal3.io_baremetalhosts.yaml