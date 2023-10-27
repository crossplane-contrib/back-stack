install:
  bash ./local-install.sh

reset:
  kind delete cluster --name backstack

update-catalog:
  git add backstage/catalog
  git commit -m "Update backstage catalog"
  git push origin main
