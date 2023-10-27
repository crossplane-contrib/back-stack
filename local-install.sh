#!/bin/bash
# import helpers
. scripts/common.sh

# set up kind cluster
kind create cluster --name backstack --wait 5m --config=- <<- EOF
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"        
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      protocol: TCP
EOF

# build backstage
pushd backstage
yarn install --frozen-lockfile
yarn tsc
yarn build:backend --config ../../app-config.yaml

docker image build . -f packages/backend/Dockerfile --tag backstage:1.0.0

kind load docker-image backstage:1.0.0 --name backstack
popd

# configure ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s 

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

# configure provider-kubernetes for crossplane
kubectl create -f - <<- EOF
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-kubernetes
    spec:
      package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.9.0
EOF
kubectl wait provider/provider-kubernetes --for=condition=Healthy --timeout=1m
SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|crossplane-system:|g')
kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
kubectl create -f - <<- EOF
    apiVersion: kubernetes.crossplane.io/v1alpha1
    kind: ProviderConfig
    metadata:
      name: local
    spec:
      credentials:
        source: InjectedIdentity
EOF

# install hub composition
kubectl apply -f crossplane/apis/hub
waitfor default crd hubs.backstack.cncf.io
kubectl wait crd/hubs.backstack.cncf.io --for=condition=Established --timeout=1m

# get config
loadenv ./.env

# deploy hub
kubectl apply -f - <<-EOF
    apiVersion: backstack.cncf.io/v1alpha1
    kind: Hub
    metadata:
      name: hub
    spec: 
      parameters:
        clusterId: local
        repository: ${REPOSITORY}
        backstage:
          host: backstage-7f000001.nip.io
        argocd:
          host: argocd-7f000001.nip.io
EOF

# deploy secrets
waitfor default ns argocd
kubectl create -f - <<-EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: clusters
      namespace: argocd
      labels:
        argocd.argoproj.io/secret-type: repository
    stringData:
      type: git
      url: ${REPOSITORY}
      password: ${GITHUB_TOKEN}
      username: back-stack
EOF

waitfor default ns backstage
kubectl create -f - <<-EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: backstage
      namespace: backstage
    stringData:
      GITHUB_TOKEN: ${GITHUB_TOKEN}
EOF

waitfor argocd secret argocd-initial-admin-secret
ARGO_INITIAL_PASSWORD=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

# ready to go!
echo ""
echo "
Your BACK Stack is ready!

Backstage: https://backstage-7f000001.nip.io
ArgoCD: https://argocd-7f000001.nip.io
  username: admin
  password ${ARGO_INITIAL_PASSWORD}
"
