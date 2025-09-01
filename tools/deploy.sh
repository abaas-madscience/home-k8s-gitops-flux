#!/bin/sh
kubectl run -it --rm --restart=Never debug --image=busybox --namespace=n8n -- sh
