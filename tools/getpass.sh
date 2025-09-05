#!/bin/sh
kubectl get secret n8n-postgres-app -n n8n -o jsonpath='{.data.password}' | base64 --decode
