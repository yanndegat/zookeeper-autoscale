FROM jplock/zookeeper:3.4.8

ENV DOCKER_BASE_VERSION=0.0.4 \
    CONSUL_TEMPLATE_VERSION=0.15.0

RUN addgroup zk && adduser -S -G zk zk

# Set up certificates, our base tools, and Consul.
RUN apk add --no-cache jq curl ca-certificates gnupg openssl && \
    gpg --recv-keys 91A6E7F85D05C65630BEF18951852D87348FFC4C && \
    mkdir -p /tmp/build && \
    cd /tmp/build && \
    wget https://releases.hashicorp.com/docker-base/${DOCKER_BASE_VERSION}/docker-base_${DOCKER_BASE_VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/docker-base/${DOCKER_BASE_VERSION}/docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/docker-base/${DOCKER_BASE_VERSION}/docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS.sig && \
    gpg --batch --verify docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS.sig docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS && \
    grep ${DOCKER_BASE_VERSION}_linux_amd64.zip docker-base_${DOCKER_BASE_VERSION}_SHA256SUMS | sha256sum -c && \
    unzip docker-base_${DOCKER_BASE_VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS.sig && \
    gpg --batch --verify consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS.sig consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS && \
    grep ${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip consul-template_${CONSUL_TEMPLATE_VERSION}_SHA256SUMS | sha256sum -c && \
    unzip consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip && \
    cp bin/gosu bin/dumb-init consul-template /bin && \
    cd /tmp && \
    rm -rf /tmp/build && \
    apk del gnupg && \
    rm -rf /root/.gnupg

#patch waiting for consul-template 0.16 release
COPY ./consul-template /bin/consul-template

ENV CLUSTER_ID="MYCLUSTER" \
    DOCKER_INSPECT_HOST="localhost" \
    CONSUl_HOST="localhost" \
    CONSUL_PORT=8500 \
    CONSUL_USESSL=0 \
    CONSUL_CACERT="" \
    CONSUL_CERT="" \
    CONSUL_KEY="" \
    CONSUL_API_TOKEN=""

EXPOSE 2181 2888 3888

RUN mkdir -p /var/lib/zookeeper /tmp/zookeeper && chown -R zk /opt/zookeeper /tmp/zookeeper /var/lib/zookeeper

VOLUME ["/tmp/zookeeper", "/certs", "/var/lib/zookeeper"]

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/start-zk"]

COPY ./docker-entrypoint.sh /
COPY ./consul.inc.sh /
COPY ./start-zk /
