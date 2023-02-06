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

package dev

import (
	"github.com/spf13/cobra"

	devcleanupcmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/dev/cleanup"
	devsetupcmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/dev/setup"
)

// Cobra creates and returns the `dev` command.
func Cobra() *cobra.Command {
	result := &cobra.Command{
		Use:    "dev",
		Short:  "Development utilities",
		Args:   cobra.NoArgs,
		Hidden: true,
	}
	result.AddCommand(devcleanupcmd.Cobra())
	result.AddCommand(devsetupcmd.Cobra())
	return result
}