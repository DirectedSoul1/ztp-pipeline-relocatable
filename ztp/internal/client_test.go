/*
Copyright 2022 Red Hat Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
*/

package internal

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

var _ = Describe("Client", func() {
	var (
		ctx    context.Context
		logger logr.Logger
	)

	BeforeEach(func() {
		var err error

		// Create a context:
		ctx = context.Background()

		// Create the logger:
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetLevel(1).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Can't be created without a logger", func() {
		client, err := NewClient().Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("logger"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(client).To(BeNil())
	})

	It("Can retrieve information from the cluster", func() {
		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(client).ToNot(BeNil())

		// Retrieve the list of pods:
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())
	})

	It("Writes to the log the details of the request and response", func() {
		// Create a logger that writes to a memory buffer and with the level 3 enabled, as
		// that is the level used for the detail of HTTP requests and responses:
		buffer := &bytes.Buffer{}
		logger, err := logging.NewLogger().
			SetWriter(io.MultiWriter(buffer, GinkgoWriter)).
			SetLevel(3).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Send a first request to force the client to do all the initial requests that it
		// does to retrieve metadata, we are not interested in that.
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())

		// Clear the log buffer and send the request again so that we can analyze the result
		// of that particular request:
		buffer.Reset()
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())
		lines := strings.Split(buffer.String(), "\n")

		// There should be at least three messages: sending the request header, received the
		// response header and received the response body. Note that there may be more if
		// the response body is fragmented.
		Expect(len(lines)).To(BeNumerically(">=", 3))
		type Message struct {
			Msg    string `json:"msg"`
			Method string `json:"method"`
			URL    string `json:"url"`
			Code   int    `json:"code"`
			N      int    `json:"n"`
		}
		var message Message

		// The first message should contain the details of the request:
		err = json.Unmarshal([]byte(lines[0]), &message)
		Expect(err).ToNot(HaveOccurred())
		Expect(message.Msg).To(Equal("Sending request"))
		Expect(message.Method).To(Equal("GET"))
		Expect(message.URL).To(MatchRegexp("^https://.*/api/v1/pods$"))

		// The second message should contain the details of the response:
		err = json.Unmarshal([]byte(lines[1]), &message)
		Expect(err).ToNot(HaveOccurred())
		Expect(message.Msg).To(Equal("Received response"))
		Expect(message.Code).To(Equal(200))
	})

	It("Processes requests in order", func() {
		// The first wrapper marks the request:
		first := RequestTransformer(func(request *http.Request) *http.Request {
			defer GinkgoRecover()
			request.Header.Set("X-My-Mark", "my-value")
			return request
		})

		// The second wrapper checks that the mark is present:
		second := RequestTransformer(func(request *http.Request) *http.Request {
			defer GinkgoRecover()
			Expect(request.Header.Get("X-My-Mark")).To(Equal("my-value"))
			return request
		})

		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			AddWrapper(first).
			AddWrapper(second).
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(client).ToNot(BeNil())

		// Retrieve the list of pods:
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())
	})

	It("Processes responses in reversed order", func() {
		// The first wrapper checks that the mark is present:
		first := ResponseTransformer(func(r *http.Response, e error) (*http.Response, error) {
			defer GinkgoRecover()
			Expect(r.Header.Get("X-My-Mark")).To(Equal("my-value"))
			return r, e
		})

		// The second wrapper marks the response:
		second := ResponseTransformer(func(r *http.Response, e error) (*http.Response, error) {
			defer GinkgoRecover()
			r.Header.Set("X-My-Mark", "my-value")
			return r, e
		})

		// Create the client:
		client, err := NewClient().
			SetLogger(logger).
			AddWrapper(first).
			AddWrapper(second).
			Build()
		Expect(err).ToNot(HaveOccurred())
		Expect(client).ToNot(BeNil())

		// Retrieve the list of pods:
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())
	})

	It("Writes to the log afer wrappers process request", func() {
		// Create a logger that writes to a memory buffer and with the level 3 enabled, as
		// that is the level used for the detail of HTTP requests and responses:
		buffer := &bytes.Buffer{}
		logger, err := logging.NewLogger().
			SetWriter(io.MultiWriter(buffer, GinkgoWriter)).
			SetLevel(3).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create a logging wrapper configured to write request headers:
		wrapper, err := logging.NewTransportWrapper().
			SetLogger(logger).
			SetHeaders(true).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client with a wrapper that adds a request header:
		client, err := NewClient().
			SetLogger(logger).
			SetLoggingWrapper(wrapper).
			AddWrapper(RequestTransformer(func(r *http.Request) *http.Request {
				r.Header.Set("X-My-Mark", "my-value")
				return r
			})).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Make sure that at least one request is sent:
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())

		// Check that the header has been written to the log:
		text := buffer.String()
		Expect(text).To(ContainSubstring("X-My-Mark"))
		Expect(text).To(ContainSubstring("my-value"))
	})

	It("Doesn't write to the log the initial metadata requests", func() {
		// Create a logger that writes to a memory buffer and with the level 3 enabled, as
		// that is the level used for the detail of HTTP requests and responses:
		buffer := &bytes.Buffer{}
		logger, err := logging.NewLogger().
			SetWriter(io.MultiWriter(buffer, GinkgoWriter)).
			SetLevel(3).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client with a wrapper that adds a request header:
		client, err := NewClient().
			SetLogger(logger).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Send a request:
		list := &corev1.PodList{}
		err = client.List(ctx, list)
		Expect(err).ToNot(HaveOccurred())

		// Check that the metadata requests haven't been written to the log:
		text := buffer.String()
		Expect(text).ToNot(ContainSubstring(`/api?`))
		Expect(text).ToNot(ContainSubstring(`/api/v1?`))
		Expect(text).ToNot(ContainSubstring(`/apis?`))
		Expect(text).ToNot(ContainSubstring(`/apis/apps/v1?`))

		// Check that the data request has been written to the log:
		Expect(text).To(ContainSubstring(`/api/v1/pods"`))
	})
})
