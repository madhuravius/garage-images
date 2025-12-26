.PHONY: build run test help

IMAGE_NAME ?= garage
RUST_VERSION ?= latest

help:
	@echo "Available targets:"
	@echo "  make build       - Build the Docker image"
	@echo "  make run         - Run the Docker container and show version"
	@echo "  make test        - Test that Garage starts successfully"
	@echo "  make help        - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  IMAGE_NAME       - Docker image name (default: $(IMAGE_NAME))"
	@echo "  RUST_VERSION     - Rust version to build with (default: $(RUST_VERSION))"

build:
	docker build --build-arg RUST_VERSION=$(RUST_VERSION) -t $(IMAGE_NAME):latest .

run:
	docker run -it --rm $(IMAGE_NAME):latest garage version

test:
	@echo "Testing Garage startup..."
	docker run --rm -d --name garage-test $(IMAGE_NAME):latest /garage server > /dev/null 2>&1 && \
	sleep 2 && \
	(docker exec garage-test /garage version > /dev/null 2>&1 && echo "✓ Garage is running successfully" || echo "✗ Garage failed to start") ; \
	docker stop garage-test > /dev/null 2>&1 || true
