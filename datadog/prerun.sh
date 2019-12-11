#!/usr/bin/env bash

case $DYNOTYPE in
    run)
        DISABLE_DATADOG_AGENT="true"
        ;;
    web)
        cat >> "$DD_CONF_DIR/conf.d/process.d/conf.yaml" <<EOF
  - name: gunicorn-worker
    search_string: ['^gunicorn: worker']
    exact_match: false
  - name: gunicorn-master
    search_string: ['^gunicorn: master']
    exact_match: false
EOF
        ;;
    engine)
        cat >> "$DD_CONF_DIR/conf.d/process.d/conf.yaml" <<EOF
  - name: celery-main
    # [celeryd: celery@aeade076-e94d-452f-8af0-ad8d5850fa4c:MainProcess] -active- (worker --beat --app mergifyio.synchronizator --concurrency 4 --queues schedule,github.accounts,github.events,celery)
    search_string: ['\[celeryd: .+:MainProcess\]']
    exact_match: false
  - name: celery-worker
    # [celeryd: celery@aeade076-e94d-452f-8af0-ad8d5850fa4c:ForkPoolWorker-2]
    search_string: ['\[celeryd: .+:ForkPoolWorker']
    exact_match: false
  - name: celery-beat
    # celery-beat
    search_string: ['[celery beat]']
EOF
        ;;
esac


# Only the first web dyno will monitor redis
if [ "$DYNO" == "web.1" ]; then
    REDIS_REGEX='^redis://([^:]+):([^@]+)@([^:]+):([^/]+)$'

    if [ -n "$MERGIFYENGINE_STORAGE_URL" ]; then
        if [[ $MERGIFYENGINE_STORAGE_URL =~ $REDIS_REGEX ]]; then
        sed -i "s/<CACHE HOST>/${BASH_REMATCH[3]}/" "$DD_CONF_DIR/conf.d/redisdb.d/conf.yaml"
        sed -i "s/<CACHE PASSWORD>/${BASH_REMATCH[2]}/" "$DD_CONF_DIR/conf.d/redisdb.d/conf.yaml"
        sed -i "s/<CACHE PORT>/${BASH_REMATCH[4]}/" "$DD_CONF_DIR/conf.d/redisdb.d/conf.yaml"
        fi
    fi


    if [ -n "$MERGIFYENGINE_CELERY_BROKER_URL" ]; then
        if [[ $MERGIFYENGINE_CELERY_BROKER_URL =~ $REDIS_REGEX ]]; then
            sed -i "s/<CELERY HOST>/${BASH_REMATCH[3]}/" "$DD_CONF_DIR/conf.d/redisdb.d/conf.yaml"
            sed -i "s/<CELERY PASSWORD>/${BASH_REMATCH[2]}/" "$DD_CONF_DIR/conf.d/redisdb.d/conf.yaml"
            sed -i "s/<CELERY PORT>/${BASH_REMATCH[4]}/" "$DD_CONF_DIR/conf.d/redisdb.d/conf.yaml"
        fi
    fi

else
    rm -f $DD_CONF_DIR/conf.d/redisdb.d/conf.yaml
fi