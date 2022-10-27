oci ce cluster create-kubeconfig --cluster-id $cluster_id --file $HOME/.kube/config --region ca-toronto-1 --token-version 2.0.0  --kube-endpoint PUBLIC_ENDPOINT

alias k=kubectl


helm repo add bitnami https://charts.bitnami.com/bitnami
vi jenkins-values.yaml
helm install jenkins bitnami/jenkins -f jenkins-values.yaml

