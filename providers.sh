kubectl create -f - <<-EOF
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
        name: provider-azure-storage
    spec:
        package: xpkg.upbound.io/upbound/provider-azure-storage:v0.38.2
EOF