set -e
set -o pipefail

BITCOIND_ONION="$(cat /var/lib/tor/onion/bitcoind/hostname)"
CLIGHTNING_NODEID=$(sudo -u clightning lightning-cli --lightning-dir=/var/lib/clightning getinfo | jq -r '.id')
CLIGHTNING_ONION="$(cat /var/lib/tor/onion/clightning/hostname)"
CLIGHTNING_ID="$CLIGHTNING_NODEID@$CLIGHTNING_ONION:9735"

echo BITCOIND_ONION="$BITCOIND_ONION"
echo CLIGHTNING_NODEID="$CLIGHTNING_NODEID"
echo CLIGHTNING_ONION="$CLIGHTNING_ONION"
echo CLIGHTNING_ID="$CLIGHTNING_ID"

NGINX_ONION_FILE=/var/lib/tor/onion/nginx/hostname
if [ -e "$NGINX_ONION_FILE" ]; then
    NGINX_ONION="$(cat $NGINX_ONION_FILE)"
    echo NGINX_ONION="$NGINX_ONION"
fi

LIQUIDD_ONION_FILE=/var/lib/tor/onion/liquidd/hostname
if [ -e "$LIQUIDD_ONION_FILE" ]; then
    LIQUIDD_ONION="$(cat $LIQUIDD_ONION_FILE)"
    echo LIQUIDD_ONION="$LIQUIDD_ONION"
fi

SPARKWALLET_ONION_FILE=/var/lib/tor/onion/spark-wallet/hostname
if [ -e "$SPARKWALLET_ONION_FILE" ]; then
    SPARKWALLET_ONION="$(cat $SPARKWALLET_ONION_FILE)"
    echo SPARKWALLET_ONION="http://$SPARKWALLET_ONION"
fi

ELECTRS_ONION_FILE=/var/lib/tor/onion/electrs/hostname
if [ -e "$ELECTRS_ONION_FILE" ]; then
    ELECTRS_ONION="$(cat $ELECTRS_ONION_FILE)"
    echo ELECTRS_ONION="$ELECTRS_ONION"
fi

SSHD_ONION_FILE=/var/lib/tor/onion/sshd/hostname
if [ -e "$SSHD_ONION_FILE" ]; then
    SSHD_ONION="$(cat $SSHD_ONION_FILE)"
    echo SSHD_ONION="$SSHD_ONION"
fi
