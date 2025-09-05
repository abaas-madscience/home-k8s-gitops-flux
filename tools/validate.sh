#!/bin/bash
# validate-crosslinks.sh

echo "Validating Gateway → HTTPRoute → Service → Deployment crosslinks..."

fail=0

# Pull all Gateways
gateways=$(kubectl get gateway -A --no-headers | awk '{print $2 "," $1}')

# Pull all Services
services=$(kubectl get svc -A --no-headers | awk '{print $2 "," $1}')

# Pull all Deployments
deployments=$(kubectl get deploy -A --no-headers | awk '{print $2 "," $1}')

# Check HTTPRoutes
for route in $(kubectl get httproute -A --no-headers | awk '{print $2 "," $1}'); do
  route_name=$(echo "$route" | cut -d',' -f1)
  route_ns=$(echo "$route" | cut -d',' -f2)

  # Check parentRefs
  parent_name=$(kubectl get httproute $route_name -n $route_ns -o jsonpath='{.spec.parentRefs[0].name}')
  parent_ns=$(kubectl get httproute $route_name -n $route_ns -o jsonpath='{.spec.parentRefs[0].namespace}')
  if ! echo "$gateways" | grep -q "$parent_name,$parent_ns"; then
    echo "ERROR: HTTPRoute $route_name/$route_ns references missing Gateway $parent_name/$parent_ns"
    fail=1
  fi

  # Check backendRefs
  backend_name=$(kubectl get httproute $route_name -n $route_ns -o jsonpath='{.spec.rules[0].backendRefs[0].name}')
  backend_ns=$route_ns  # assume same namespace
  if ! echo "$services" | grep -q "$backend_name,$backend_ns"; then
    echo "ERROR: HTTPRoute $route_name/$route_ns references missing Service $backend_name/$backend_ns"
    fail=1
  fi

  # Check if Deployment exists for Service (best effort)
  selector=$(kubectl get svc $backend_name -n $backend_ns -o jsonpath='{.spec.selector.app}' 2>/dev/null)
  if [[ "$selector" != "" ]]; then
    if ! echo "$deployments" | grep -q "$selector,$backend_ns"; then
      echo "WARNING: Service $backend_name/$backend_ns points to missing Deployment app=$selector"
      # Not hard-fail — maybe it's static service
    fi
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "Validation failed! ❌"
  exit 1
else
  echo "All Gateway → HTTPRoute → Service → Deployment links validated. ✅"
fi
