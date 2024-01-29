FROM alpine:3.19

ARG SYNPUF_URL=SECRET01
ARG SYNPUF1K_URL=SECRET02
ARG CDS_URL=SECRET03

RUN apk add --no-cache \
  curl \
  bash \
  postgresql-client

USER 10001
WORKDIR /opt/omop_init/sources

RUN curl -Ss ${SYNPUF_URL} -o SynPUF.tar.gz
RUN curl -Ss ${SYNPUF1K_URL} -o synpuf1k.tar.gz
RUN curl -Ss ${CDS_URL} -o cds.tar.gz

WORKDIR /opt/omop_init

COPY --chown=10001:10001 init_cds init_cds
COPY --chown=10001:10001 init_synpuf init_synpuf
COPY --chown=10001:10001 init_post init_post
COPY --chown=10001:10001 setup.sh setup.sh

ENTRYPOINT ["/opt/omop_init/setup.sh"]
