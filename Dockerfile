FROM nginx:1.30-alpine

# busybox in the base image already provides crond, wget, and flock.
# We only need git for clone/pull and tini to reap crond's children
# (nginx runs as PID 1 via exec and doesn't itself reap).
RUN apk add --no-cache git tini \
    && rm -rf /var/cache/apk/*

WORKDIR /srv

COPY nginx.conf       /etc/nginx/nginx.conf
COPY entrypoint.sh    /usr/local/bin/entrypoint.sh
COPY update.sh        /usr/local/bin/update.sh
COPY crontab          /etc/crontabs/root

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/update.sh

ENV REPO_URL=https://github.com/kemalsanli/umtx2.git \
    REPO_REF=main \
    REPO_DIR=/srv/umtx2 \
    DOC_ROOT_SUBPATH=document/en/ps5

EXPOSE 80

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
