FROM rust:1.95-bookworm AS build
WORKDIR /build
COPY Cargo.toml Cargo.lock schema.sql ./
COPY src ./src
RUN cargo build --release --locked

FROM debian:bookworm-slim
RUN useradd --uid 10001 --create-home ranked && mkdir /data && chown ranked:ranked /data
COPY --from=build /build/target/release/timemaster-ranked /usr/local/bin/timemaster-ranked
USER ranked
ENV RANKED_DATABASE=/data/ranked.sqlite3 RANKED_REQUIRE_TLS=true RANKED_TRUST_PROXY=true RANKED_BIND=0.0.0.0:8000
EXPOSE 8000
CMD ["timemaster-ranked"]
