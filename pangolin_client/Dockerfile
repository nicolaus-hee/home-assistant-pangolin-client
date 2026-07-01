ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache curl jq bind-tools iptables

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]
