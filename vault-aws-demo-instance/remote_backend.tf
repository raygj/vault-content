terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "jray-hashi"
    workspaces {
      name = "aws-us-east-1-vault-int-storage-stage2"
    }
  }
}
