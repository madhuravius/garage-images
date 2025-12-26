# ---- build stage ----
ARG RUST_VERSION=latest
ARG GARAGE_VERSION=v2
FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION} AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG GARAGE_VERSION

WORKDIR /build

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install cross-compilation tools if needed
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ] && [ "$BUILDPLATFORM" != "linux/arm64" ]; then \
        apt-get update && apt-get install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        && rm -rf /var/lib/apt/lists/* \
        && rustup target add aarch64-unknown-linux-gnu; \
    fi

RUN if [ "$TARGETPLATFORM" = "linux/amd64" ] && [ "$BUILDPLATFORM" != "linux/amd64" ]; then \
        apt-get update && apt-get install -y \
        gcc-x86-64-linux-gnu \
        g++-x86-64-linux-gnu \
        && rm -rf /var/lib/apt/lists/* \
        && rustup target add x86_64-unknown-linux-gnu; \
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

RUN <<EOF
#!/bin/bash
set -e

case "$TARGETPLATFORM" in
    "linux/arm64")
        export RUSTFLAGS="-C target-cpu=generic -C target-feature=-aes,-sha2"
        if [ "$BUILDPLATFORM" != "linux/arm64" ]; then
            export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
            export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
            export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++
            cargo build --release --target aarch64-unknown-linux-gnu
            cp target/aarch64-unknown-linux-gnu/release/garage /garage-binary
        else
            cargo build --release
            cp target/release/garage /garage-binary
        fi
        ;;
    "linux/amd64")
        # Standard x86_64 build
        export RUSTFLAGS="-C target-cpu=x86-64"
        if [ "$BUILDPLATFORM" != "linux/amd64" ]; then
            export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=x86_64-linux-gnu-gcc
            export CC_x86_64_unknown_linux_gnu=x86_64-linux-gnu-gcc
            export CXX_x86_64_unknown_linux_gnu=x86_64-linux-gnu-g++
            cargo build --release --target x86_64-unknown-linux-gnu
            cp target/x86_64-unknown-linux-gnu/release/garage /garage-binary
        else
            cargo build --release
            cp target/release/garage /garage-binary
        fi
        ;;
    *)
        echo "Unsupported platform: $TARGETPLATFORM"
        exit 1
        ;;
esac
EOF

# ---- runtime stage ----
FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /garage-binary /garage

ENV RUST_BACKTRACE=1
ENV RUST_LOG=garage=info

CMD ["/garage", "server"]
