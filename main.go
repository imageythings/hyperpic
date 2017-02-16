// Copyright 2017 Axel Etcheverry. All rights reserved.
// Use of this source code is governed by a MIT
// license that can be found in the LICENSE file.

package main

var (
	AppName = "image-service"
)

func main() {
	config := NewConfiguration()

	server := NewServer(config)

	server.ListenAndServe()
}
