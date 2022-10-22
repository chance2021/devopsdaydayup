#resource "oci_core_instance" "bastion_instance" {
#    # Required
#    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
#    compartment_id = var.compartment_ocid
#    shape = var.instance_shape
#    source_details {
#        source_id = var.source_ocid
#        source_type = "image"
#    }
#
#    # Optional
#    display_name = var.instance_name
#    create_vnic_details {
#        assign_public_ip = true
#        subnet_id = module.bastion-vcn.vcn_id
#    }
#    metadata = {
#        ssh_authorized_keys = file(var.ssh_public_key_path)
#    } 
#    preserve_boot_volume = false
#}
