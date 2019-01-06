#!/bin/bash

# NOTE:
# kubernetes instances should be up and running in GCP
# gcloud CLI tool should be installed and configured
# kubectl CLI tool should be installed

# TODO: try to simplify duplicated code

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kube-ip-address \
                            --region $(gcloud config get-value compute/region) \
                            --format 'value(address)')

# create configs for worker nodes
for node in worker-0 worker-1 worker-2; do
  kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${node}.kubeconfig

  kubectl config set-credentials system:node:${node} \
    --client-certificate=${node}.pem \
    --client-key=${node}-key.pem \
    --embed-certs=true \
    --kubeconfig=${node}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:node:${node} \
    --kubeconfig=${node}.kubeconfig

  kubectl config use-context default --kubeconfig=${node}.kubeconfig
done

# create config for kube-proxy
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# create config for kube-controller-manager
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# create config for kube-scheduler
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# create config for admin
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes \
    --user=admin \
    --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

# TODO: use ansible!
# upload config files
for node in worker-0 worker-1 worker-2; do
  gcloud compute scp ${node}.kubeconfig kube-proxy.kubeconfig ${node}:~/
done

for node in controller-0 controller-1 controller-2; do
  gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${node}:~/
done

# generate and upload encryption config
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat encrypt-config-template.yaml | sed "s/ENCRYPTION_KEY/${ENCRYPTION_KEY}" > encryption-config.yaml

for node in controller-0 controller-1 controller-2; do
  gcloud compute scp encryption-config.yaml ${node}:~/
done