storage "raft" {
  path    = "/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
  #tls_cert_file = "/vault/vault.crt"
  #tls_key_file  = "/vault/vault.key"
  #tls_client_ca_file = "/vault/vault.ca"
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
ui = true
disable_mlock = true
max_lease_ttl = "8784h"
default_lease_ttl = "8784h"

