FROM rust:1.95-bookworm AS build
WORKDIR /build
COPY Cargo.toml Cargo.lock schema.sql ./
COPY src ./src
RUN cargo build --release --locked

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends gosu && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 10001 --create-home ranked && mkdir /data && chown ranked:ranked /data
COPY --from=build /build/target/release/timemaster-ranked /usr/local/bin/timemaster-ranked
COPY --chmod=755 entrypoint.sh /usr/local/bin/ranked-entrypoint
ENV RANKED_DATABASE=/data/ranked.sqlite3 RANKED_REQUIRE_TLS=true RANKED_TRUST_PROXY=true
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/ranked-entrypoint"]
CMD ["timemaster-ranked"]
