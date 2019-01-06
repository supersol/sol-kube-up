#!/bin/bash

./install_etcd.sh
./install_control_plane.sh
./install_nginx.sh

kubectl apply --kubeconfig admin.kubeconfig \
                           -f kube-apiserver-to-kubelet-role.yaml

kubectl apply --kubeconfig admin.kubeconfig \
                           -f kube-apiserver-to-kubelet-role-binding.yaml