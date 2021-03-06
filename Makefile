.PHONY: all clean deps fmt vet test docker

EXECUTABLE ?= hyperpic
IMAGE ?= hyperscale/$(EXECUTABLE)
IMAGE_TEST ?= $(IMAGE)-test
IMAGE_DEV ?= $(IMAGE)-dev
VERSION ?= $(shell git describe --match 'v[0-9]*' --dirty='-dev' --always)
COMMIT ?= $(shell git rev-parse --short HEAD)

PACKAGES = $(shell go list ./... | grep -v /vendor/)

HYPERPIC_AUTH_SECRET ?= c8da8ded-f9a2-429c-8811-9b2a07de8ede

release:
	@echo "Release v$(version)"
	@git pull
	@git checkout master
	@git pull
	@git checkout develop
	@git flow release start $(version)
	@echo "$(version)" > .version
	@sed -e "s/version: .*/version: \"v$(version)\"/g" docs/swagger.yaml > docs/swagger.yaml.new && rm -rf docs/swagger.yaml && mv docs/swagger.yaml.new docs/swagger.yaml
	@git add .version docs/swagger.yaml
	@git commit -m "feat(project): update version file" .version docs/swagger.yaml
	@git flow release finish $(version)
	@git push
	@git push --tags
	@git checkout master
	@git push
	@git checkout develop
	@echo "Release v$(version) finished."

all: deps build test

clean:
	@go clean -i ./...

deps:
	@glide install

fmt:
	@go fmt $(PACKAGES)

vet:
	@go vet $(PACKAGES)

test:
	@CGO_LDFLAGS_ALLOW="-fopenmp" go test ./...

cover:
	@CGO_LDFLAGS_ALLOW="-fopenmp" go test -cover -covermode=set -coverprofile=coverage.out ./...
	@go tool cover -func ./coverage.out

docker:
	@sudo docker build --no-cache=true --rm -t $(IMAGE) .

dev-test-docker:
	@sudo docker build -f Dockerfile.test --rm -t $(IMAGE_TEST) .

dev-run-docker:
	@sudo docker build -f Dockerfile.dev --rm -t $(IMAGE_DEV) .

publish: docker
	@sudo docker tag $(IMAGE) $(IMAGE):latest
	@sudo docker push $(IMAGE)

asset/bindata.go: docs/index.html docs/swagger.yaml
	@echo "Bin data..."
	@go-bindata -pkg asset -o asset/bindata.go docs/

$(EXECUTABLE): $(shell find . -type f -print | grep -v vendor | grep "\.go") asset/bindata.go
	@echo "Building $(EXECUTABLE)..."
	@CGO_ENABLED=1 go build ./cmd/hyperpic

build: $(EXECUTABLE)

run: docker
	@sudo docker run -e "HYPERPIC_AUTH_SECRET=c8da8ded-f9a2-429c-8811-9b2a07de8ede" -p 8574:8080 -v $(shell pwd)/var/lib/hyperpic:/var/lib/hyperpic --rm $(IMAGE)

dev: $(EXECUTABLE)
	@./$(EXECUTABLE)

dev-test: dev-test-docker
	@sudo docker run --rm $(IMAGE_TEST)

dev-run: dev-run-docker
	@sudo docker run -e "HYPERPIC_AUTH_SECRET=c8da8ded-f9a2-429c-8811-9b2a07de8ede" -p 8574:8080 -v $(shell pwd)/var/lib/hyperpic:/var/lib/hyperpic --rm $(IMAGE_DEV)

heroku:
	@echo "Deploy Hyperpic on Heroku..."
	@heroku container:push web --app=hyperpic

upload-demo:
	@curl -F 'image=@_resources/demo/kayaks.jpg' -H "Authorization: Bearer $(HYPERPIC_AUTH_SECRET)" https://hyperpic.herokuapp.com/kayaks.jpg
	@curl -F 'image=@_resources/demo/smartcrop.jpg' -H "Authorization: Bearer $(HYPERPIC_AUTH_SECRET)" https://hyperpic.herokuapp.com/smartcrop.jpg
