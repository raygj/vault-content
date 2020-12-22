- start with a working Vault Agent Configuration

tee ~/auto-auth-conf.hcl <<EOF
exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "/home/jray/lab_ca.crt"
            client_cert = "/home/jray/vault-client.crt"
            client_key = "/home/jray/vault-client.key"
        }
    }

    sink "file" {
        config = {
            path = "/home/jray/vault-token-via-agent/here_is_your_token"
        }
    }
}

vault {
  address = "https://vault-ent-node-1:8200"
}

template {
destination = "/home/jray/secret.txt"
contents = <<EOT

{{ with secret "demo/myapp/config/" }}
{{ .Data.current_password }}
{{ end }}

EOT
}
EOF

- run Vault Agent manually in debug mode:

vault agent -config=/home/jray/auto-auth-conf.hcl -log-level=debug

- validate that the template pulled the current_password:

more /home/jray/secret.txt
