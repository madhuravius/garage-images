# ---- build stage ----
ARG RUST_VERSION=latest
ARG GARAGE_VERSION=v2
FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION} AS builder

ARG TARGETARCH
ARG GARAGE_VERSION

WORKDIR /build

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone Garage repository and checkout specified version
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

# Set Rust target and compilation flags based on architecture
RUN case "$TARGETARCH" in \
    amd64) \
      echo "Building for x86_64..." && \
      rustup target add x86_64-unknown-linux-gnu && \
      RUSTFLAGS="-C target-cpu=generic -C opt-level=3" \
      cargo build --release --target x86_64-unknown-linux-gnu && \
      cp target/x86_64-unknown-linux-gnu/release/garage /garage-binary; \
      ;; \
    arm64) \
      echo "Building for aarch64..." && \
      rustup target add aarch64-unknown-linux-gnu && \
      RUSTFLAGS="-C target-cpu=generic -C opt-level=3" \
      cargo build --release --target aarch64-unknown-linux-gnu && \
      cp target/aarch64-unknown-linux-gnu/release/garage /garage-binary; \
      ;; \
    *) \
      echo "Unsupported architecture: $TARGETARCH" && \
      exit 1; \
      ;; \
    esac

# ---- runtime stage ----
FROM scratch

COPY --from=builder /garage-binary /garage

ENV RUST_BACKTRACE=1
ENV RUST_LOG=garage=info

CMD ["/garage", "server"]
