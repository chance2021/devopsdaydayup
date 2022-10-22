terraform apply -var-file=config/dev.tfvars

export compartment_id="<compartment ocid>"
export tenancy_id="<tenancy ocid>"
export availability_domain_name="<availability domain name>"
export shape_name="VM.Standard.E2.1.Micro"
export instance_display_name="oci-created-vm-`date +%Y%m%d%H%M`"
export image_id="ocid1.image.oc1.ca-toronto-1.aaaaaaaaf6jdknqhsavxre2dfdioc5qwudy2zhlhmpdyybi7pxcmgwtddqqa"
export subnet_id="<subnet ocid>"
export path_to_authorized_keys_file="/home/<username>/.ssh/id_rsa.pub"

echo "compartment_id is $compartment_id"
echo "tenancy_id is $tenancy_id"
echo "availability_domain_name is $availability_domain_name"
echo "shape_name is $shape_name"
echo "instance_display_name is $instance_display_name"
echo "image_id is $image_id"
echo "subnet_id is $subnet_id"
echo "path_to_authorized_keys_file is $path_to_authorized_keys_file"

oci os ns get

oci iam compartment list -c $tenancy_id

oci compute image list -c $compartment_id

oci compute instance launch --availability-domain $availability_domain_name -c $compartment_id --shape $shape_name   --display-name $instance_display_name   --image-id $image_id --ssh-authorized-keys-file $path_to_authorized_keys_file --subnet-id  $subnet_id
