#!/usr/bin/env bash
set +x
source /usr/lib/bashio/bashio.sh

BIN_PATH="/data/pangolin-cli"
VERSION_FILE="/data/pangolin-cli.version"
GITHUB_REPO="fosrl/cli"

mkdir -p /data

# bashio::config returns the literal string "null" (not empty) for an
# optional field whose key is entirely absent from options.json, which
# bashio::var.has_value treats as a non-empty value. Normalize that here so
# optional fields behave as actually-empty when unset.
normalize_optional() {
    [ "$1" = "null" ] && echo "" || echo "$1"
}

CLIENT_ID=$(bashio::config 'client_id')
CLIENT_SECRET=$(bashio::config 'client_secret')
ENDPOINT=$(bashio::config 'endpoint')
ORG_ID=$(normalize_optional "$(bashio::config 'org_id')")
AUTO_UPDATE=$(bashio::config 'auto_update')
PINNED_VERSION=$(normalize_optional "$(bashio::config 'pinned_version')")
LOG_LEVEL=$(bashio::config 'log_level')

# --- DNS takeover (aliases option) is disabled, see flush_dns_dnat/setup_dns_dnat
# below and config.yaml — kept commented out instead of deleted so it's easy to
# re-enable once the unrelated Supervisor bug it depends on is fixed.
# ALIASES=$(bashio::config 'aliases')
# [ "${ALIASES}" = "null" ] && ALIASES=""
#
# # hassio_dns's own address, captured before pangolin-cli's `--override-dns`
# # rewrites /etc/resolv.conf to point at the tunnel's loopback resolver. Used
# # later to query the hassio-internal `dns.local.hass.io`/`supervisor.local.hass.io`
# # names for the DNAT setup below (see setup_dns_dnat).
# ORIGINAL_DNS=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
#
# DNS_DNAT_TAG="pangolin_client_dns_takeover"

case "$(uname -m)" in
    x86_64) ASSET_ARCH="amd64" ;;
    aarch64) ASSET_ARCH="arm64" ;;
    *) bashio::exit.nok "Unsupported architecture: $(uname -m)" ;;
esac
ASSET_NAME="pangolin-cli_linux_${ASSET_ARCH}"

resolve_release_json() {
    if bashio::var.has_value "${PINNED_VERSION}"; then
        curl -fsSL --connect-timeout 10 --max-time 30 "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${PINNED_VERSION}"
    else
        curl -fsSL --connect-timeout 10 --max-time 30 "https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    fi
}

download_binary() {
    local release_json="$1"
    local tag download_url
    tag=$(echo "${release_json}" | jq -r '.tag_name')
    download_url=$(echo "${release_json}" | jq -r --arg name "${ASSET_NAME}" '.assets[] | select(.name == $name) | .browser_download_url')

    if [ -z "${tag}" ] || [ "${tag}" = "null" ] || [ -z "${download_url}" ] || [ "${download_url}" = "null" ]; then
        bashio::log.warning "Could not resolve a release/asset (arch: ${ASSET_NAME})."
        return 1
    fi

    local current_version=""
    [ -f "${VERSION_FILE}" ] && current_version=$(cat "${VERSION_FILE}")

    if [ "${current_version}" = "${tag}" ] && [ -x "${BIN_PATH}" ]; then
        bashio::log.info "pangolin-cli already at version ${tag}, skipping download."
        return 0
    fi

    bashio::log.info "Downloading pangolin-cli ${tag} (${ASSET_NAME})..."
    if curl -fsSL --connect-timeout 10 --max-time 120 -o "${BIN_PATH}.tmp" "${download_url}"; then
        chmod +x "${BIN_PATH}.tmp"
        mv "${BIN_PATH}.tmp" "${BIN_PATH}"
        echo "${tag}" > "${VERSION_FILE}"
        bashio::log.info "pangolin-cli updated to ${tag}."
        return 0
    else
        bashio::log.warning "Download of pangolin-cli ${tag} failed."
        rm -f "${BIN_PATH}.tmp"
        return 1
    fi
}

NEED_UPDATE=false
if bashio::var.has_value "${PINNED_VERSION}"; then
    NEED_UPDATE=true
elif bashio::var.true "${AUTO_UPDATE}"; then
    NEED_UPDATE=true
fi

if [ "${NEED_UPDATE}" = true ] || [ ! -x "${BIN_PATH}" ]; then
    RELEASE_JSON=$(resolve_release_json) || RELEASE_JSON=""
    if [ -n "${RELEASE_JSON}" ]; then
        download_binary "${RELEASE_JSON}" || bashio::log.warning "Falling back to cached binary, if any."
    else
        bashio::log.warning "Could not reach GitHub API to check for updates."
    fi
fi

if [ ! -x "${BIN_PATH}" ]; then
    bashio::exit.nok "No pangolin-cli binary available (no cache and download failed)."
fi

ARGS=(up --attach --id "${CLIENT_ID}" --secret "${CLIENT_SECRET}" --endpoint "${ENDPOINT}" --log-level "${LOG_LEVEL}")
if bashio::var.has_value "${ORG_ID}"; then
    ARGS+=(--org "${ORG_ID}")
fi

# --- DNS takeover (aliases option) is disabled. The mechanism below is fully
# implemented and was verified live (DNAT in PREROUTING gets hassio_dns's/
# Supervisor's DNS queries to pangolin-cli's loopback resolver, working around
# hassio_dns's isolated network namespace the same way the official Tailscale
# add-on's magicdns-ingress-proxy-forwarding does for MagicDNS). It's commented
# out only because making Supervisor's CoreDNS actually use that path hits a
# separate, unrelated Supervisor bug, so right now it has no visible effect.
# Re-enable by uncommenting this block plus the `aliases` schema/options entry
# in config.yaml, the translations entry, and `setup_dns_dnat &`/`flush_dns_dnat`
# below.
#
# flush_dns_dnat() {
#     local rule
#     while IFS= read -r rule; do
#         iptables -t nat -D PREROUTING ${rule#-A PREROUTING }
#     done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -- "${DNS_DNAT_TAG}")
# }
#
# setup_dns_dnat() {
#     if ! bashio::var.has_value "${ALIASES}"; then
#         bashio::log.info "DNS takeover: no 'aliases' option configured, skipping."
#         return
#     fi
#     if [ -z "${ORIGINAL_DNS}" ]; then
#         bashio::log.warning "DNS takeover: no pre-tunnel DNS server found in /etc/resolv.conf, skipping."
#         return
#     fi
#
#     local resolver_ip=""
#     for _ in $(seq 1 30); do
#         resolver_ip=$(awk '/^nameserver 100\./{print $2; exit}' /etc/resolv.conf)
#         [ -n "${resolver_ip}" ] && break
#         sleep 2
#     done
#     if [ -z "${resolver_ip}" ]; then
#         bashio::log.warning "DNS takeover: pangolin-cli did not set a local resolver in time, skipping."
#         return
#     fi
#     bashio::log.info "DNS takeover: redirecting hassio_dns/Supervisor DNS queries to ${resolver_ip}:53"
#
#     local hassio_dns_ip supervisor_ip ip
#     while true; do
#         hassio_dns_ip=$(dig +short "@${ORIGINAL_DNS}" dns.local.hass.io A | head -n1)
#         supervisor_ip=$(dig +short "@${ORIGINAL_DNS}" supervisor.local.hass.io A | head -n1)
#
#         flush_dns_dnat
#         for ip in "${hassio_dns_ip}" "${supervisor_ip}"; do
#             [ -z "${ip}" ] && continue
#             iptables -t nat -A PREROUTING -i hassio -s "${ip}" -p udp --dport 53 \
#                 -m comment --comment "${DNS_DNAT_TAG}" -j DNAT --to-destination "${resolver_ip}:53"
#             iptables -t nat -A PREROUTING -i hassio -s "${ip}" -p tcp --dport 53 \
#                 -m comment --comment "${DNS_DNAT_TAG}" -j DNAT --to-destination "${resolver_ip}:53"
#         done
#         bashio::log.info "DNS takeover: active for hassio_dns=${hassio_dns_ip:-none} supervisor=${supervisor_ip:-none}"
#
#         sleep 60
#     done
# }

ip link delete pangolin 2>/dev/null || true

bashio::log.info "Starting pangolin-cli..."
"${BIN_PATH}" "${ARGS[@]}" &
PANGOLIN_PID=$!
trap 'kill -TERM "${PANGOLIN_PID}" 2>/dev/null' TERM INT

wait "${PANGOLIN_PID}"
