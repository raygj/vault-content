# comparable vault native commands
# vault policy write edu-policy - <<EOT path "secret/education/*" {
# capabilities = [ "create", "read", "update", "delete", "list" ] }
# EOT

# provider requires VAULT_ADDR and VAULT_TOKEN env vars
provider "vault" {}

# create a policy
data "vault_policy"document" "education" {
  rule {
    path = "secret/data/education/*"
    capabilities = ["create","read","update", "delete","list"]
  }
}

resource "vault_policy" "education" {
  name = "edu-policy"
  policy = "${data.vault_policy_document.hcl}"
}

# enable KV secrets engine
resource "vault_mount" "kv-edu" {
  path = "secret"
  type = "kv-v2"
}