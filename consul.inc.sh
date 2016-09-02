#!/bin/bash -x
DOCKER_INSPECT_HOST=${DOCKER_INSPECT_HOST}
CONSUl_HOST=${CONSUL_HOST}
CONSUL_PORT=${CONSUL_PORT:-8500}
CONSUL_USESSL=${CONSUL_USESSL:-1}
CONSUL_CACERT=${CONSUL_CACERT:-ca.pem}
CONSUL_CERT=${CONSUL_CERT:-cert.pem}
CONSUL_KEY=${CONSUL_KEY:-cert-key.pem}
CONSUL_API_TOKEN=${CONSUL_API_TOKEN:-}

## retrieve container name from yanndegat/docker-inspect service
###
containername() {
    curl --fail http://$DOCKER_INSPECT_HOST/container/$(hostname) | jq '.Name' | sed 's/"//g' | cut -d'/' -f2
}

## CONSUL BASIC MECHANICS
###
call_consul(){
    METHOD=$1
    shift
    path=$1
    shift

    if [ "$CONSUL_USESSL" == 1 ]; then
        /usr/bin/curl --silent --fail \
                      --cacert /certs/$CONSUL_CACERT \
                      --cert /certs/$CONSUL_CERT \
                      --key /certs/$CONSUL_KEY \
                      -X"$METHOD" "https://$CONSUL_HOST:$CONSUL_PORT/v1$path" "$@"
    else
        /usr/bin/curl --silent --fail \
                      -X"$METHOD" "http://$CONSUL_HOST:$CONSUL_PORT/v1$path" "$@"
    fi
}

consul_new_session(){
    TMPFILE=$(mktemp)
    cat > "$TMPFILE" <<EOF
{"Name":"$(hostname)", "TTL": "60s", "LockDelay" : "60s"}
EOF
    call_consul PUT "/session/create" \
           -d @"$TMPFILE" | jq '.ID' | sed 's/"//g' > /tmp/consul_zk.session
    rm "$TMPFILE"
    echo "$CONTAINER_NAME created session $(cat /tmp/consul_zk.session)" >&2

    cat /tmp/consul_zk.session
}

consul_cluster_lock(){
    CLUSTER_ID=$1
    touch /tmp/consul_zk.session
    SESSION_ID=$(cat /tmp/consul_zk.session)
    echo "$CONTAINER_NAME locking session $SESSION_ID" >&2
    if [ ! -z "$SESSION_ID" ]; then
        call_consul PUT "/session/renew/$SESSION_ID" >&2
        if [ $? != 0 ]; then
            SESSION_ID=$(consul_new_session)
        fi
    else
        SESSION_ID=$(consul_new_session)
    fi

    # if LOCKED : consul returns "true"
    call_consul PUT "/kv/zk_nodes/${CLUSTER_ID}-lock?acquire=$SESSION_ID"
}

consul_cluster_unlock(){
    CLUSTER_ID=$1
    SESSION_ID=$(cat /tmp/consul_zk.session)
    echo "$CONTAINER_NAME unlocking session $SESSION_ID" >&2
    if [ ! -z "$SESSION_ID" ]; then
        # if LOCKED : consul returns "true"
        call_consul PUT "/kv/zk_nodes/${CLUSTER_ID}-lock?release=$SESSION_ID"
    else
        echo "Missing session" >&2
        echo false
    fi
}

consul_cluster_lock_timeout(){
    now=$(date +%s)
    timeout=$(( now + 60 ))
    set +e
    while :; do
        if [[ $timeout -lt $(date +%s) ]]; then
            echo "timeout! could not acquire lock" >&2
            echo false
        fi
        LOCK=$(consul_cluster_lock $@)
        echo "response from consul lock: $LOCK" >&2
        [[ $LOCK == "true" ]] && echo true && break
        sleep 1
    done
}


## HACK/TRICK : Zookeeper's cluster definition consist of a list of static list servers,
## each server having been assigned a uniq numeric id.
## The job here is to be able to assign each "docker container name" (which will be the dns name) a
## unique id, and make it publicly available so that each container can build the static list of servers that will
## form the cluster. We will store these data in consul. Maybe it would be great to be able to store this directly in zookeeper.
##
## Note: to ensure the id is unique, we increment the last id of servers list, with a lock.
## There are obvioulsy better ways to achieve this. but this is a good starting point.
## maybe the "CreateIndex" in consul
###
consul_cluster_nodes_ids() {
    CLUSTER_ID=$1
    for i in $(call_consul GET /kv/zk_nodes/${CLUSTER_ID}/?recurse | jq '.[].Value' | grep -v null | sed 's/"//g' ); do
        echo $(echo $i | base64 -d);
    done
}

consul_cluster_next_id(){
    CLUSTER_ID=$1
    NODES_IDS=$(consul_cluster_nodes_ids $CLUSTER_ID)

    if [ -z "$NODES_IDS" ]; then
        echo 1
    else
        echo $(($(IFS=" "; echo $NODES_IDS | sort -nr | head -1) + 1))
    fi
}

consul_register_node(){
    CLUSTER_ID=$1
    if [[ "$(consul_cluster_lock_timeout $CLUSTER_ID)" == "true" ]]; then
        NODE_ID=$(consul_cluster_next_id $CLUSTER_ID)
        call_consul PUT /kv/zk_nodes/$CLUSTER_ID/$CONTAINER_NAME -d $NODE_ID >&2
        consul_cluster_unlock $CLUSTER_ID > /dev/null 2>&1
        echo $NODE_ID
    else
        echo "cloudn't register node within timeout" >&2
        echo false
    fi
}

if [ "$CONSUL_USESSL" == 1 ]; then
    if [ -z "$CONSUL_CACERT" ] || [ ! -f "/certs/$CONSUL_CACERT" ]; then
        echo "CONSUL_CACERT is not set" >&2
        exit 1
    fi

    if [ -z "$CONSUL_CERT" ] || [ ! -f "/certs/$CONSUL_CERT" ]; then
        echo "CONSUL_CERT is not set" >&2
        exit 1
    fi
    if [ -z "$CONSUL_KEY" ] || [ ! -f "/certs/$CONSUL_KEY" ]; then
        echo "CONSUL_KEY is not set" >&2
        exit 1
    fi
fi

if [ -z "$CONSUL_HOST" ]; then
    echo "CONSUL_HOST is not set" >&2
    exit 1
fi
if [ -z "$DOCKER_INSPECT_HOST" ]; then
    echo "DOCKER_INSPECT_HOST is not set" >&2
    exit 1
fi

if [ -z "$CONSUL_PORT" ]; then
    echo "CONSUL_PORT is not set" >&2
    exit 1
fi

if [ -z "$CONSUL_HOST" ]; then
    echo "CONSUL_HOST not set." >&2
    exit 1
fi

CONTAINER_NAME=$(containername)
