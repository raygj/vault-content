# comparable vault native commands
# vault write auth/github/config organization="my-organization" 
# vault write auth/github/map/teams/education value="edu-policy"

# provider requires VAULT_ADDR and VAULT_TOKEN env vars
provider "vault" {}

# enable auth method
resource "vault_auth_backend" "github" {
  type = "github"
}

resource "vault_github_auth_backend" "github" {
  organization = "my-organization"
}

# configure github auth method - map a team
resource "vault_github_team" "education" {
  backend = vault_github_auth_backend.github.id
  team = "education"
  token_policies = ["edu-policy"]
}