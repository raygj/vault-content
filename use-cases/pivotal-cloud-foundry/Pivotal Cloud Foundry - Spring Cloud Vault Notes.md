# Pivotal Cloud Foundry - Spring Cloud Vault Notes

## Net-Net Opinion

- Vault Service Broker was a stop-gap solution that will not be required once Vault PCF Auth Plugin is GA
- PCF Auth Plugin relies on PCF Container Identity Assurance, which relies on PCF 2.1 (April 2018, latest version is 2.6) and CredHub...so both of these are prerequisites for the plugin


## History

Vault Service Broker (VSB) is used to bootstrap PCF so that PCF can securely store, access, and encrypt with Vault.

- VSB is currently opinionated (4 mountpoints and namespace are hardcoded)
	- this means cross-DC failover is not supported
	- namespaces do not comply with customer-implemented naming standards

### Interacting with Vault

- Spring Cloud Vault is a native library that abstracts interactions with Vault
- Spring Cloud config files:

`pom.xml` manages dependencies
`application.yaml` defines app characterists
`bootstrap.yaml` injects Vault values as env vars

- once app has Vault token and address as env vars, it can interact with Vault as a Java object

### Challenges

- How to get a Vault token and its address?
- How to isolate secrets per app?
- How to make everything dynamic (automated)?

#### Vault PCF Service Broker Addresses Challenges
[LINK](https://github.com/hashicorp/vault-service-broker) to Service Broker

- Vault Service Broker (VSB) is code created by HashiCorp to support integration to PCF
- VSB on PCF solves secure introduction
- VSB provides dynamic policy generation
- Due to the nature of this integration and PCF functionality, each instance of an app will share creds

[BLOG POST](https://www.hashicorp.com/blog/cloud-foundry-vault-service-broker) with more info

- VSB does not need to run under PCF, but it is registered with PCF (binding)

### Limitations

- VSB is not used by the app to interact with Vault
	- app talks to Vault directly
- VSB does not initialize secrets
	- workflow to get secret to app is:
1. once app has token, dev could use CURL to retrieve secret
1. Vault admin via ticket provides secret
1. PCF admin retrieves secret

- VSB will access 4 mount points only

```
Mount the generic backend at /cf/<organization_id>/secret/
Mount the generic backend at /cf/<space_id>/secret/
Mount the generic backend at /cf/<instance_id>/secret/
Mount the transit backend at /cf/<instance_id>/transit/
```

- could customize source code or done manually

# Path Forward

## Vault Plugin
[LINK](https://github.com/hashicorp/vault-plugin-auth-pcf)

## Uses Instance Identity (cert) via PCF App Container Identity Assurance
[LINK](https://content.pivotal.io/blog/new-in-pcf-2-1-app-container-identity-assurance-via-automatic-cert-rotation)

```
Starting in PCF 1.12, the Pivotal Application Service tile issues a unique certificate for each running app instance. This mechanism encodes the identity of the application instance on the platform in several different ways. Further, the certificate is valid for only 24 hours.
```

```
So if any other service trusts PCF’s certificate authority, it is then set up to authenticate the application instances running on it, and then to authorize them based on the application metadata.
```

## Interesting "Known Risk"

```
This authentication engine uses PCF's instance identity service to authenticate users to Vault. Because PCF makes its CA certificate and private key available to certain users at any time, it's possible for someone with access to them to self-issue identity certificates that meet the criteria for a Vault role, allowing them to gain unintended access to Vault.
```