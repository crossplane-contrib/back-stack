install:
  bash ./local-install.sh

reset:
  kind delete cluster --name backstack

update-catalog:
  git pull origin main
  git add backstage/catalog
  git commit -m "Update backstage catalog"
  git push origin main

rebuild-backstage:
  #!/bin/bash
  pushd backstage
  yarn install --frozen-lockfile
  yarn tsc
  yarn build:backend --config ../../app-config.yaml

  docker image build . -f packages/backend/Dockerfile --tag backstage:1.0.0

  kind load docker-image backstage:1.0.0 --name backstack
  popd
  
  kubectl get pods -n backstage -o name | xargs kubectl delete -n backstage

apply-spoke:
  kubectl apply -f ./crossplane/apis/hub/composition.yaml
  kubectl apply -f ./crossplane/apis/spoke/definition.yaml
  kubectl apply -f ./crossplane/apis/spoke/composition.yaml
