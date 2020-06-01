
### Enter values for the following variables before you run the script###

#PRI VAULT HOST/IP
PRI_HOST=< IP address >
#PERF VAULT HOST/IP
PERF_HOST=< IP address >

# USE HTTP / HTTPS as per use case
PRI_ADDR=http://$PRI_HOST:8200
PERF_ADDR=http://$PERF_HOST:8200

#PRI TOKEN
PRI_TOKEN="< token >"
#PERF TOKEN
PERF_TOKEN="< token >"

# assumes Vault was iniitated with a single Shamir key, if dev instance, then comment out all keyShare lines
keyShare_1="< some value of Shamir key"


################################################

empty_char () {
echo "###################################"
}
# UNSEAL USING COMMAND LINE
# Make sure you put operator keys as per vault threshold config
# Here we have threshold key as 3
unseal_env () {
# vault operator unseal {abcdxyz} >&-
vault operator unseal $keyShare_1  >&-

echo "vault unsealed "
}
vault_secret_read () {
empty_char
date
echo $VAULT_ADDR
#vault status
# VAULT DYNAMIC SECRET ROLE USED is test1
secret_read=$(vault read database/static-creds/test1 --format=json)
#echo $secret_read >> output.log
password_rcvd=$(jq -n "$secret_read" |jq '.data.password')
ttl=$(jq -n "$secret_read" |jq '.data.ttl')
echo $password_rcvd
echo $ttl
empty_char

}

echo "GET PRI secret"

export VAULT_ADDR=$PRI_ADDR
vault login $PRI_TOKEN >&-
vault_secret_read

sleep 1

echo "GET PERF secret right before killing primary"
export VAULT_ADDR=$PERF_ADDR
vault login $PERF_TOKEN >&-
vault_secret_read

sleep 1
echo "PRI DOWN"
# update to reflect your cert name/path
ssh -i < your certificate >.pem ubuntu@$PRI_HOST sudo systemctl stop vault
sleep 1


echo "GET PERF secret-2 after killing primary"
export VAULT_ADDR=$PERF_ADDR
vault login $PERF_TOKEN >&-
vault_secret_read

sleep 120
echo "PRI UP"
read  -n 1 -p "Input Selection press ENTER:" mainmenuinput
# update to reflect your cert name/path
ssh -i < your certificate >.pem ubuntu@$PRI_HOST sudo systemctl start vault
sleep 2

# PRI UNSEAL FIRE
export VAULT_ADDR=$PRI_ADDR
sleep 1
unseal_env

sleep 10

echo "GET PRI secret-2"
export VAULT_ADDR=$PRI_ADDR
vault login $PRI_TOKEN >&-
vault_secret_read

sleep 1
echo "GET PERF secret-3"
export VAULT_ADDR=$PERF_ADDR
vault login $PERF_TOKEN >&-
vault_secret_read
