# snippet for dynamic AWS creds

```

production:{{with secret "aws/creds/deploy" }}
  lease_id: {{.Data.lease_id}}
  lease_duration: {{.Data.lease_duration}}
  lease_renewable: {{.Data.lease_renewable}}
  access_key: {{.Data.access_key}}
  secret_key: {{.Data.secret_key}}
{{end}}


``