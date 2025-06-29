FROM ubuntu:22.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sysstat \
    fio \
    bash \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY performance-test.sh /performance-test.sh
RUN chmod +x /performance-test.sh

CMD ["/performance-test.sh"]
