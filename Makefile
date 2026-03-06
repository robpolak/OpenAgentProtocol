.PHONY: build validate fmt sync-schemas

sync-schemas:
	rm -rf cmd/oap-validate/schemas
	cp -r schemas cmd/oap-validate/schemas

build: sync-schemas
	go build -o oap-validate ./cmd/oap-validate/

validate: build
	./oap-validate spec/examples/*.yaml spec/examples/personas/*.yaml

fmt:
	gofmt -w ./cmd/
