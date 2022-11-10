terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
      version = "4.96.0"
    }
  }
}
provider "oci" {
  user_ocid = "<user ocid>"
  tenancy_ocid = "<tenancy ocid>"
  #private_key_path = "<path to the private key which set in API token in My Profile>"
  fingerprint = "<fingerprint>"
  region = "ca-toronto-1"
}
