# ---- build stage ----
ARG RUST_VERSION=latest
ARG GARAGE_VERSION=v2
FROM rust:${RUST_VERSION} AS builder

ARG GARAGE_VERSION

WORKDIR /build

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

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

# Set architecture-specific RUSTFLAGS
# ARM64: disable hardware crypto (Pi 3/4 lack aes/sha2 instructions)
# AMD64: use baseline x86-64 for broad compatibility
RUN ARCH=$(uname -m) && \
    echo "Detected architecture: $ARCH" && \
    if [ "$ARCH" = "aarch64" ]; then \
      export RUSTFLAGS="-C target-cpu=generic -C target-feature=-aes,-sha2"; \
    else \
      export RUSTFLAGS="-C target-cpu=x86-64"; \
    fi && \
    echo "Using RUSTFLAGS: $RUSTFLAGS" && \
    cargo build --release && \
    cp target/release/garage /garage-binary

# ---- runtime stage ----
FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /garage-binary /garage

ENV RUST_BACKTRACE=1
ENV RUST_LOG=garage=info

CMD ["/garage", "server"]
