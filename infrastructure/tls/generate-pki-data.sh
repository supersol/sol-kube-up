#!/bin/bash

# NOTE:
# kubernetes instances should be up and running in GCP
# gcloud CLI tool should be installed and configured

# generate CA key and cert using CloudFlare sll tool
echo "Generating root CA"
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# generate admin key/cert
cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes admin-csr.json | cfssljson -bare admin

# generate kubelet certs/keys
for node in worker-0 worker-1 worker-2; do
    echo "Generating workers certificates"
    cat node-csr-template.json | sed "s/NODE_NAME/${node}" > "${node}-csr.json"

    external_ip=$(gcloud compute instances describe ${node} \
                  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

    internal_ip=$(gcloud compute instances describe ${node} \
                  --format 'value(networkInterfaces[0].networkIP)')

    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -hostname=${node},${external_ip},${internal_ip} \
      -profile=kubernetes \
      ${node}-csr.json | cfssljson -bare ${node}
done

# generate kube-controller-manager cert/key
echo "Generating kube-controller-manager certificates"
cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes \
       kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

# generate kube-proxy cert/key
echo "Generating kube-proxe certificates"
cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes \
      kube-proxy-csr.json | cfssljson -bare kube-proxy

# generate kube-scheduler cert/key
echo "Generating kube-scheduler certificates"
cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=ca-config.json \
      -profile=kubernetes \
      kube-scheduler-csr.json | cfssljson -bare kube-scheduler

# generate cert/key for api server
echo "Generating API server certificate"
kubernetes_public_address=$(gcloud compute addresses describe kube-ip-address \
                            --region $(gcloud config get-value compute/region) \
                            --format 'value(address)')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${kubernetes_public_address},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# generate service account cert/key
echo "Generating service account certificate"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

# TODO: automate with ansible
# upload certificates and keys
#for node in worker-0 worker-1 worker-2; do
#  gcloud compute scp ca.pem ${node}-key.pem ${node}.pem ${node}:~/
#done
#
#for node in controller-0 controller-1 controller-2; do
#  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
#    service-account-key.pem service-account.pem ${node}:~/
#done
