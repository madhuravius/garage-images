# Garage Image

A lightweight Docker image with Garage, an S3-compatible object storage system with automatic geo-replication.

## About

[Garage](https://garagehq.deuxfleurs.fr/) is a simplified, self-contained, and self-healing alternative to MinIO for object storage. This image provides a pre-built, optimized binary for easy deployment.

## Quick Start

### Build
```bash
make build
```

### Run
```bash
docker run -it --rm ghcr.io/username/garage:v2 /garage version
```

## Build Arguments

- `GARAGE_VERSION` - Garage version to build (default: `v2`)
  - Supports semantic version prefixes like `v2` to automatically resolve to the latest `v2.x.x` release
  - Can specify exact versions like `v2.1.0`

```bash
# Use latest v2.x.x
make build

# Use specific version
make build GARAGE_VERSION=v2.1.0

# Use latest v1.x.x
make build GARAGE_VERSION=v1
```

- `RUST_VERSION` - Rust compiler version (default: `latest`)

```bash
make build RUST_VERSION=1.75
```

## Supported Architectures

- `amd64` (x86_64) - Generic x86-64
- `arm64` (aarch64) - ARM64 (including Raspberry Pi 4 Model B)

## Multi-Architecture Builds

Build for both architectures:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t garage:v2 .
```

## Releases

Images are automatically built and pushed to GHCR on:
- Every push to `main`
- Daily at midnight UTC

Tags:
- `:v2` - Latest stable Garage v2.x
- `:v2-<TIMESTAMP>` - Timestamped release for reproducibility

## Credits

* [Garage](https://garagehq.deuxfleurs.fr/)
* [Deuxfleurs](https://deuxfleurs.fr/)
