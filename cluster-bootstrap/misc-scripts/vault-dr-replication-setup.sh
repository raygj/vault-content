Vault Replication setup

read -rs ROOT_TOKEN
 <enter the token>
 export VAULT_TOKEN=${ROOT_TOKEN}


read -rs DR_ROOT_TOKEN
 <enter the token>

export VAULT_PRIMARY_ADDR=http://vault.primary:8200 
export VAULT_SECONDARY_ADDR=http://vault.secondary:8200

vault_primary () {

VAULT_ADDR=${VAULT_PRIMARY_ADDR} vault $@ 

}



vault_secondary () {

  VAULT_ADDR=${VAULT_SECONDARY_ADDR} vault $@

}



####DR Replication:

export VAULT_TOKEN=${ROOT_TOKEN}
vault_primary login ${ROOT_TOKEN}
vault_primary write -f /sys/replication/dr/primary/enable

sleep 10

PRIMARY_DR_TOKEN=$(vault_primary write -format=json /sys/replication/dr/primary/secondary-token id=ptfe_secondary | jq --raw-output '.wrap_info .token' )

#vault_primary write -format=json /sys/replication/dr/primary/revoke-secondary id=ptfe_secondary

echo $PRIMARY_DR_TOKEN

vault_primary read sys/replication/dr/status

export VAULT_TOKEN=${DR_ROOT_TOKEN}

vault_secondary login $DR_ROOT_TOKEN

vault_secondary write -f /sys/replication/performance/secondary/disable

vault_secondary write /sys/replication/dr/secondary/enable token=${PRIMARY_DR_TOKEN} primary_adi_addr=${VAULT_PRIMARY_ADDR}

vault_secondary read sys/replication/dr/status
