#!/usr/bin/env bash
#
# Docker entrypoint for Teku with validator registration
#
# Same password is used for all validator keystore and withdraw keystore
# to keep simple
#############################################################################

EP_KEY_PATH=${EP_KEY_PATH:-/opt/teku/keys}
EP_DEPOSIT_AMOUNT=${EP_DEPOSIT_AMOUNT:-32000000000}
EP_ETH1_CLIENT_URL=${EP_ETH1_CLIENT_URL:-http://besu:8545}
EP_VALIDATOR_COUNT=${EP_VALIDATOR_COUNT:-64}

_PASSWORD_FILE=$EP_KEY_PATH/password.txt
_TEKU_CONFIG_FILE=/opt/teku/teku.yml
_TEKU_DATA_PATH=/opt/teku/data

mkdir -p $EP_KEY_PATH $_TEKU_DATA_PATH

# Save the password to file
echo $EP_KEYSTORE_VALIDATOR_PASSWORD > $_PASSWORD_FILE

# Logging functions
log()
{
  echo "$(date '+%Y-%m-%d %H:%M') $1"
}

error()
{
  log "$1"
  exit 1
}

############
# Main
############

# Check parameters
[[ -z $EP_DEPOSIT_CONTRACT_ADDRESS ]] && error "Environment variable EP_DEPOSIT_CONTRACT_ADDRESS is empty"
[[ -z $EP_ETH1_PRIVATE_KEY ]] && error "Environment variable EP_ETH1_PRIVATE_KEY is empty"
[[ -z $EP_KEYSTORE_VALIDATOR_PASSWORD ]] && error "Environment variable EP_KEYSTORE_VALIDATOR_PASSWORD is empty"
[[ -z $EP_KEYSTORE_WITHDRAW_PASSWORD ]] && error "Environment variable EP_KEYSTORE_WITHDRAW_PASSWORD is empty"
[[ -z $EP_ETH1_ENDPOINT ]] && error "Environment variable EP_ETH1_ENDPOINT is empty"

# Prepare variables
counter=$(eval echo {1..$EP_VALIDATOR_COUNT})
validator_key_files=''
validator_key_password_files=''

# Temporary file to save command output
tmp_file=$(mktemp)

# Loop through validator key generation
log "Starting the validator generation and registration"
for count in $counter
do
  # Register validator keys
  yes | /opt/teku/bin/teku validator generate-and-register \
                           --eth1-private-key=$EP_ETH1_PRIVATE_KEY \
                           --deposit-amount-gwei=$EP_DEPOSIT_AMOUNT \
                           --eth1-endpoint=$EP_ETH1_CLIENT_URL \
                           --keys-output-path=$EP_KEY_PATH \
                           --eth1-deposit-contract-address=$EP_DEPOSIT_CONTRACT_ADDRESS \
                           --network=minimal \
                           --encrypted-keystore-validator-password-file=$_PASSWORD_FILE \
                           --encrypted-keystore-withdrawal-password-file=$_PASSWORD_FILE > $tmp_file || error "Failed to generate and register validator key"

  #
  key_file=$(grep "_validator.json" $tmp_file | sed 's/.*\[\(.*_validator.json\)\].*/\1/g')
  validator_key_files="$validator_key_files $key_file"
  validator_key_password_files="$validator_key_password_files $_PASSWORD_FILE"

  # Log progress after every 4
  [[ $(expr $count % 4 ) -eq 0 ]] && log "Registered ${count}/${EP_VALIDATOR_COUNT} validators"
done
log "Complete validator generation and registration"

# Convert to CSV list of values. Assume no leading and training spaces
validator_key_files=$(echo $validator_key_files | sed 's/ /,/g')
validator_key_password_files=$(echo $validator_key_password_files | sed 's/ /,/g')


# Generate teku.yml config file
log "Generating teku configuration file"
cat <<EOF > $_TEKU_CONFIG_FILE
# network
network: "minimal"

# p2p
# p2p-enabled options:
# false - no discovery, only connect to static peers
# true - Enable discovery v5
p2p-enabled: True
p2p-interface: "0.0.0.0"
p2p-port: 9000
p2p-advertised-ip: "$(hostname -i)"
p2p-advertised-port: 9000
p2p-discovery-enabled: True

# interop
# when genesis time is set to 0, artemis takes genesis time as currentTime + 5 seconds.
Xinterop-genesis-time: 0
Xinterop-owned-validator-start-index: 0
Xinterop-owned-validator-count: 64
Xinterop-number-of-validators: 64
Xinterop-enabled: False

# deposit
eth1-deposit-contract-address: "$EP_DEPOSIT_CONTRACT_ADDRESS"
eth1-endpoint: "$EP_ETH1_ENDPOINT"

# logging
log-color-enabled: False

# metrics
metrics-enabled: True
metrics-port: 8008
metrics-interface : "0.0.0.0"
metrics-categories: ["BEACON","LIBP2P","NETWORK","EVENTBUS","JVM","PROCESS","STORAGE","VALIDATOR"]
metrics-host-allowlist: ["*"]

# database
data-path: "$_TEKU_DATA_PATH"
data-storage-mode: "prune"

# beaconrestapi
rest-api-port: 5051
rest-api-docs-enabled: False
rest-api-enabled: True
rest-api-interface: "0.0.0.0"
rest-api-host-allowlist: ["*"]

validators-key-files: $validator_key_files
validators-key-password-files: $validator_key_password_files
EOF


# Start Teku
log "Starting teku"
exec /opt/teku/bin/teku -c $_TEKU_CONFIG_FILE
