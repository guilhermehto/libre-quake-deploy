# ---- build FTEQW dedicated server ----
FROM debian:bookworm-slim AS build
ARG FTEQW_REF=master
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates build-essential zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FTEQW_REF} https://github.com/fte-team/fteqw.git /src
WORKDIR /src/engine
RUN make sv-rel FTE_TARGET=linux64 -j"$(nproc)" \
 && cp release/fteqw-sv64 /fteqw-sv

# ---- fetch LibreQuake server data ----
FROM debian:bookworm-slim AS data
ARG LQ_VERSION=v0.09-beta
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /server.zip \
      https://github.com/lavenderdotpet/LibreQuake/releases/download/${LQ_VERSION}/server.zip \
 && unzip -q /server.zip -d /tmp \
 && mkdir -p /lq1 && cp -r /tmp/server/* /lq1/ && rm -rf /lq1/docs

# ---- runtime ----
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends zlib1g ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -m -d /srv/quake quake
WORKDIR /srv/quake
COPY --from=build /fteqw-sv ./fteqw-sv
COPY --from=data /lq1 ./lq1
COPY config/server.cfg ./lq1/server.cfg
# manifest so FTE recognises the game without id1/pak files
RUN printf 'FTEMANIFEST 1\nGAME librequake\nNAME "LibreQuake"\nBASEGAME lq1\n' > default.fmf
RUN chown -R quake:quake /srv/quake
USER quake
EXPOSE 27500/udp
# FTE dedicated auto-execs lq1/server.cfg
ENTRYPOINT ["./fteqw-sv", "-basedir", "/srv/quake"]
CMD []
