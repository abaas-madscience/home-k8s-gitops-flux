#!/bin/bash
flux create helmrelease signoz \
  --chart signoz \
  --source HelmRepository/signoz.flux-system \
  --release-name signoz \
  --target-namespace signoz \
  --create-target-namespace \
  --values values.yaml \
  --chart-version 0.90.1
