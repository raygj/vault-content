//--------------------------------------------------------------------
// Resources

resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 7

  tags = {
    Name      = "${var.environment_name}-vault-kms-unseal-key"
    owner     = var.hashibot_reaper_owner
    region    = var.hc_region
    purpose   = var.purpose
    TTL       = var.hashibot_reaper_ttl
    terraform = var.tf_used
    workspace = var.workspace_id
  }
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.environment_name}-vault-kms-unseal-key"
  target_key_id = aws_kms_key.vault.key_id
}
