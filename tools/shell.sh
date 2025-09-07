#!/bin/bash

echo "./shell.sh NAMESPACE POD"
kubectl exec -it -n $1 $2  -- bash
