# Build stage
FROM rust:1.75 as builder

WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Create a dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies
RUN cargo build --release
RUN rm src/main.rs

# Copy source code
COPY src ./src

# Build the application
RUN touch src/main.rs && cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/target/release/rust-bracket /app/rust-bracket

# Create directory for SQLite database
RUN mkdir -p /data

# Expose port
EXPOSE 3000

# Set environment variables
ENV DATABASE_URL=sqlite:///data/bracket.db
ENV RUST_LOG=info

# Run the application
CMD ["./rust-bracket"]

