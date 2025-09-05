#!/bin/sh
flux bootstrap github \
  --owner=abaas-madscience \
  --repository=home-k8s-gitops-flux \
  --branch=kind \
  --path=clusters/kind \
  --personal \ 
  --private \
  --components=source-controller,kustomize-controller,helm-controller,notification-controller
  
