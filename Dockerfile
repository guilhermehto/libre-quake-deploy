# ---- fetch FTEQW source once so server and web client match ----
FROM debian:bookworm-slim AS source
ARG FTEQW_REF=master
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FTEQW_REF} https://github.com/fte-team/fteqw.git /src

# ---- build FTEQW dedicated server ----
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
COPY --from=source /src /src
WORKDIR /src/engine
RUN make sv-rel -j"$(nproc)" \
 && cp release/fteqw-sv /fteqw-sv

# ---- build FTEQW browser client ----
# emsdk 2.0.12 matches FTE's CI and is only published for amd64; its wasm output runs anywhere
FROM --platform=linux/amd64 emscripten/emsdk:2.0.12 AS web
COPY --from=source /src /src
WORKDIR /src/engine
RUN make web-rel -j"$(nproc)" \
 && mkdir /web && cp release/ftewebgl.js.gz release/ftewebgl.wasm.gz /web/

# ---- fetch LibreQuake data ----
FROM debian:bookworm-slim AS data
ARG LQ_VERSION=v0.09-beta
ARG LQ_RELEASES=https://github.com/lavenderdotpet/LibreQuake/releases/download/${LQ_VERSION}
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /server.zip ${LQ_RELEASES}/server.zip \
 && unzip -q /server.zip -d /tmp \
 && mkdir -p /lq1 && cp -r /tmp/server/* /lq1/ && rm -rf /lq1/docs
# FTE refuses to serve packages named pak*.pak, so the browser copies are renamed.
# The .gz siblings let FTE's http server send them compressed.
RUN curl -fsSL -o /lite.zip ${LQ_RELEASES}/lite.zip \
 && unzip -q /lite.zip 'lite/id1/pak0.pak' 'lite/id1/pak1.pak' -d /tmp \
 && mkdir -p /id1 \
 && mv /tmp/lite/id1/pak0.pak /id1/lq_lite0.pak \
 && mv /tmp/lite/id1/pak1.pak /id1/lq_lite1.pak \
 && gzip -k -9 /id1/lq_lite0.pak /id1/lq_lite1.pak

# ---- runtime ----
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends zlib1g ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -m -d /srv/quake quake
WORKDIR /srv/quake
COPY --from=build --chown=quake:quake /fteqw-sv ./fteqw-sv
COPY --from=web --chown=quake:quake /web/ ./
COPY --from=data --chown=quake:quake /id1 ./id1
COPY --from=data --chown=quake:quake /lq1 ./lq1
COPY --chown=quake:quake config/default.fmf ./default.fmf
COPY --chown=quake:quake config/server.cfg ./lq1/server.cfg
USER quake
EXPOSE 27500/udp 27500/tcp
# FTE dedicated auto-execs lq1/server.cfg
ENTRYPOINT ["./fteqw-sv", "-basedir", "/srv/quake"]
CMD []
