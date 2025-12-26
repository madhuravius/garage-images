# ---- build stage ----
ARG RUST_VERSION=latest
ARG GARAGE_VERSION=v2
ARG TARGETARCH=amd64
FROM rust:${RUST_VERSION} AS builder

ARG GARAGE_VERSION
ARG TARGETARCH

WORKDIR /build

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set architecture-specific RUSTFLAGS
# ARM64: disable hardware crypto (Pi 3/4 lack aes/sha2 instructions)
# AMD64: use baseline x86-64 for broad compatibility
# Install cross-compilation toolchain for ARM64
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      apt-get update && apt-get install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        libc6-dev-arm64-cross \
      && rm -rf /var/lib/apt/lists/* \
      && rustup target add aarch64-unknown-linux-gnu; \
    fi

RUN git clone https://github.com/deuxfleurs-org/garage.git . && \
    if echo "${GARAGE_VERSION}" | grep -qE '^v[0-9]+$'; then \
      RESOLVED_VERSION=$(git tag -l "${GARAGE_VERSION}.*" --sort=-version:refname | head -n1); \
      if [ -z "$RESOLVED_VERSION" ]; then \
        echo "No tags found matching ${GARAGE_VERSION}.*"; \
        exit 1; \
      fi; \
      git checkout "$RESOLVED_VERSION"; \
    else \
      git checkout ${GARAGE_VERSION}; \
    fi

# Build with architecture-specific settings
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
      export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc \
      export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++ \
      export RUSTFLAGS="-C target-cpu=cortex-a53 -C target-feature=-aes,-sha2,-sha3,-crypto" \
      && cargo build --release --target aarch64-unknown-linux-gnu \
      && cp target/aarch64-unknown-linux-gnu/release/garage /garage-binary; \
    else \
      export RUSTFLAGS="-C target-cpu=x86-64" \
      && cargo build --release \
      && cp target/release/garage /garage-binary; \
    fi

# ---- runtime stage ----
FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /garage-binary /garage

ENV RUST_BACKTRACE=1
ENV RUST_LOG=garage=info

COPY LICENSE /LICENSE
COPY NOTICE /NOTICE

CMD ["/garage", "server"]
