.PHONY: build build-local build-arm64 push run test help setup

IMAGE_NAME ?= garage
RUST_VERSION ?= latest
GARAGE_VERSION ?= v2
REGISTRY ?= docker.io
BUILDER_NAME ?= multiarch

help:
	@echo "Available targets:"
	@echo "  make setup        - Create buildx builder for multi-arch builds"
	@echo "  make build        - Build multi-arch Docker image (amd64 + arm64)"
	@echo "  make build-local  - Build for local architecture only"
	@echo "  make build-arm64  - Cross-compile ARM64 image (for Pi testing)"
	@echo "  make push         - Build and push multi-arch image to registry"
	@echo "  make run          - Run the Docker container and show help"
	@echo "  make test         - Test that Garage starts successfully"
	@echo "  make help         - Show this help message"

setup:
	@docker buildx inspect $(BUILDER_NAME) > /dev/null 2>&1 || \
		docker buildx create --name $(BUILDER_NAME) --driver docker-container
	docker buildx use $(BUILDER_NAME)
	docker buildx inspect --bootstrap

build: setup
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg RUST_VERSION=$(RUST_VERSION) \
		--build-arg GARAGE_VERSION=$(GARAGE_VERSION) \
		--build-arg TARGETARCH=amd64 \
		-t $(IMAGE_NAME):latest \
		-t $(IMAGE_NAME):$(GARAGE_VERSION) \
		.

build-local:
	docker build \
		--build-arg RUST_VERSION=$(RUST_VERSION) \
		--build-arg GARAGE_VERSION=$(GARAGE_VERSION) \
		--build-arg TARGETARCH=amd64 \
		-t $(IMAGE_NAME):latest \
		-t $(IMAGE_NAME):$(GARAGE_VERSION) \
		.

build-arm64: setup
	docker buildx build \
		--platform linux/arm64 \
		--build-arg RUST_VERSION=$(RUST_VERSION) \
		--build-arg GARAGE_VERSION=$(GARAGE_VERSION) \
		--build-arg TARGETARCH=arm64 \
		-t $(IMAGE_NAME):arm64 \
		--load \
		.

push: setup
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg RUST_VERSION=$(RUST_VERSION) \
		--build-arg GARAGE_VERSION=$(GARAGE_VERSION) \
		-t $(REGISTRY)/$(IMAGE_NAME):latest \
		-t $(REGISTRY)/$(IMAGE_NAME):$(GARAGE_VERSION) \
		--push \
		.

run:
	docker run -it --rm $(IMAGE_NAME):latest /garage --help

test:
	@echo "Testing Garage startup..."
	@docker run --rm $(IMAGE_NAME):latest /garage --version
