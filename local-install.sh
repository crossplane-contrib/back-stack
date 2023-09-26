#!/bin/sh

# set up kind cluster
kind create cluster --name backstack --wait 5m

# install crossplane
helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane --wait

# configure provider-helm for crossplane
kubectl create -f - <<- EOF
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-helm
    spec:
      package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.15.0
EOF
kubectl wait provider/provider-helm --for=condition=Healthy --timeout=1m
SA=$(kubectl -n crossplane-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|crossplane-system:|g')
kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
kubectl create -f - <<- EOF
    apiVersion: helm.crossplane.io/v1beta1
    kind: ProviderConfig
    metadata:
      name: local
    spec:
      credentials:
        source: InjectedIdentity
EOF

# install hub composition
kubectl apply -f crossplane/apis/hub

# deploy hub
kubectl apply -f crossplane/examples/hub.yaml


