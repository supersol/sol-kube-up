### 1. Infrastructure in GCP via Terraform
* Create pki data (tls dir)
* Create configuration data (config dir)
* bootstrap with ansible (bootstrap dir)
### 2. Install cluster via Ansible
todo:
* bash script for gen certs, get kube configs
* ansible playbook with roles: controller/worker
* systemd templates
* use ansible gcp dynamic inventory
* install jenkins after configuring kube cluster
