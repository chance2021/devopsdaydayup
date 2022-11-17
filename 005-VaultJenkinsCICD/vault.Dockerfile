FROM vault:1.12.1
WORKDIR /vault/data
COPY vault-config.hcl /vault/config/vault-config.hcl
CMD vault server -config=/vault/config/vault-config.hcl
