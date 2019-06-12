Vault DR promote

#!/usr/bin/env bash

### How to promote DR
# Use Primary Cluster Unseal Key
export UNSEAL_KEY=[Primary Cluster Unseal Key]
export DR_ROOT_TOKEN=[DR Root Token]
export VAULT_TOKEN=${DR_ROOT_TOKEN}

export VAULT_PRIMARY_ADDR=https://[Secondary Cluster Load Balancer]:8200
export VAULT_SECONDARY_ADDR=https://[Primary Cluster Load Balancer]:8200

echo "DR_ROOT_TOKEN        : $DR_ROOT_TOKEN"
echo "VAULT_TOKEN          : $VAULT_TOKEN"
echo "VAULT_PRIMARY_ADDR   : $VAULT_PRIMARY_ADDR"
echo "VAULT_SECONDARY_ADDR : $VAULT_SECONDARY_ADDR"
echo "UNSEAL_KEY           : $UNSEAL_KEY"


vault_primary () {
VAULT_ADDR=${VAULT_PRIMARY_ADDR} vault $@
}

vault_secondary () {
  VAULT_ADDR=${VAULT_SECONDARY_ADDR} vault $@
}

#vault_secondary login $DR_ROOT_TOKEN

# Generate one time password
SECONDARY_OTP_TOKEN=$(vault_secondary operator generate-root -dr-token -format=json -generate-otp)
echo "SECONDARY_OTP_TOKEN: $SECONDARY_OTP_TOKEN"

#vault_secondary delete  /sys/replication/dr/secondary/generate-operation-token/attempt
NONCE=$(curl --request PUT --data '{"otp":"'"${SECONDARY_OTP_TOKEN}"'"}' ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/generate-operation-token/attempt | jq  --raw-output '.nonce')
echo "NONCE: $NONCE"

# Run this command to determine how many times you will have to run this
curl  ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/generate-operation-token/attempt

#{"nonce":"[Nonce Key]","started":true,"progress":0,"required":1,"complete":false,"encoded_token":"","encoded_root_token":"","pgp_fingerprint":"","otp":"","otp_length":24}

#vault_secondary write -format=json /sys/replication/dr/secondary/generate-operation-token/attempt otp=${SECONDARY_OTP_TOKEN} | jq --raw-output '.nonce'

vault_secondary write -format=json /sys/replication/dr/secondary/generate-operation-token/update key=${UNSEAL_KEY} nonce=${NONCE} | jq 

ENCODED_TOKEN=$(curl --request PUT --data '{"key":"'"${UNSEAL_KEY}"'", "nonce":"'"${NONCE}"'"}' ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/generate-operation-token/update | jq  --raw-output '.encoded_token')
echo "ENCODED_TOKEN : $ENCODED_TOKEN"

# Generate a token before demoting and promoting - From the Secondary
DR_PROMOTE_TOKEN=$(vault_secondary operator generate-root -dr-token -otp=${SECONDARY_OTP_TOKEN} -decode=${ENCODED_TOKEN})
echo "DR_PROMOTE_TOKEN: $DR_PROMOTE_TOKEN"

# Scenario 1- Demote the Primary Cluster - Assume the Primary is unavailable

### Demote primary vault instance - Do this from the primary box
# Primary Root tooken
ROOT_TOKEN=[Root Token from Primary Cluster]
export VAULT_TOKEN=${ROOT_TOKEN}
echo "VAULT_TOKEN : $VAULT_TOKEN"

# Log in to the primary cluster
vault_primary login ${ROOT_TOKEN}

# Demote the Primary
vault_primary write -f /sys/replication/dr/primary/demote
vault_primary read -format=json sys/replication/status

# Go back to Secondary box
# now promote the vault cluster to DR primary/performance primary
# you will need the unseal key from the 'vault' instance (that was killed previously)
export VAULT_TOKEN=${DR_ROOT_TOKEN}
vault_secondary write -f /sys/replication/dr/secondary/promote dr_operation_token=$DR_PROMOTE_TOKEN
# check status
vault_secondary read -format=json sys/replication/status


# When The Vault Primary goes down and the Secondary is promoted, ensure that all PTFE nodes point to the Secondary (which is now promoted and active)

# Log back into the Primary node on the Primary Vault Cluster
export VAULT_PRIMARY_ADDR=https://[Primary Cluster Load Balancer]:8200
export VAULT_SECONDARY_ADDR=https://[Secondary Cluster Load Balancer]:8200

export VAULT_TOKEN=${ROOT_TOKEN}
vault_primary login ${ROOT_TOKEN}

PRIMARY_DR_TOKEN=$(vault_primary write -format=json /sys/replication/dr/primary/secondary-token id=ptfe_secondary | jq --raw-output '.wrap_info .token' )
echo "PRIMARY_DR_TOKEN : $PRIMARY_DR_TOKEN"


#--------------------------------------------------------------------
# Linking back the new Primary with the old Secondary
# Generate one time password
export VAULT_TOKEN=${DR_ROOT_TOKEN}
SECONDARY_OTP_TOKEN=$(vault_secondary operator generate-root -dr-token -format=json -generate-otp)
echo "SECONDARY_OTP_TOKEN: $SECONDARY_OTP_TOKEN"

#vault_secondary delete  /sys/replication/dr/secondary/generate-operation-token/attempt
NONCE=$(curl --request PUT --data '{"otp":"'"${SECONDARY_OTP_TOKEN}"'"}' ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/generate-operation-token/attempt | jq  --raw-output '.nonce')
echo "NONCE: $NONCE"

# Run this command to determine how many times you will have to run this
curl  ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/generate-operation-token/attempt
#{"nonce":"053d583a-d233-5d1b-0751-75a216162f23","started":true,"progress":0,"required":1,"complete":false,"encoded_token":"","encoded_root_token":"","pgp_fingerprint":"","otp":"","otp_length":24}

#vault_secondary write -format=json /sys/replication/dr/secondary/generate-operation-token/attempt otp=${SECONDARY_OTP_TOKEN} | jq --raw-output '.nonce'
#vault_secondary write -format=json /sys/replication/dr/secondary/generate-operation-token/update key=${UNSEAL_KEY} nonce=${NONCE} | jq
ENCODED_TOKEN=$(curl --request PUT --data '{"key":"'"${UNSEAL_KEY}"'", "nonce":"'"${NONCE}"'"}' ${VAULT_SECONDARY_ADDR}/v1/sys/replication/dr/secondary/generate-operation-token/update | jq  --raw-output '.encoded_token')
echo "ENCODED_TOKEN : $ENCODED_TOKEN"

# Generate a token before demoting and promoting - From the Secondary
DR_PROMOTE_TOKEN=$(vault_secondary operator generate-root -dr-token -otp=${SECONDARY_OTP_TOKEN} -decode=${ENCODED_TOKEN})
echo "DR_PROMOTE_TOKEN: $DR_PROMOTE_TOKEN"



#--------------------------------------------------------------------
export VAULT_TOKEN=${DR_ROOT_TOKEN}
vault_secondary write -f  /sys/replication/dr/secondary/update-primary dr_operation_token=${DR_PROMOTE_TOKEN} token=${PRIMARY_DR_TOKEN} primary_adi_addr=${VAULT_PRIMARY_ADDR}
