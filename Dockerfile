# ---- build stage ----
ARG RUST_VERSION=latest
ARG GARAGE_VERSION=v2
FROM rust:${RUST_VERSION} AS builder

ARG TARGETARCH
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

# Just build for the native target
RUN cargo build --release && \
    cp target/release/garage /garage-binary

# ---- runtime stage ----
FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /garage-binary /garage

ENV RUST_BACKTRACE=1
ENV RUST_LOG=garage=info

CMD ["/garage", "server"]
