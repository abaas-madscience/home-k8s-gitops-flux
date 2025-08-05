#!/bin/bash
# validate-httproute-parentrefs.sh

echo "Checking HTTPRoute parentRefs..."

fail=0

for file in $(git diff --cached --name-only | grep -E '.*\.yaml$'); do
  if grep -q 'kind: HTTPRoute' "$file"; then
    parent_namespace=$(yq e '.spec.parentRefs[0].namespace' "$file")
    if [[ "$parent_namespace" != "infra-gateway" ]]; then
      echo "ERROR: $file has wrong parentRef namespace: $parent_namespace"
      fail=1
    fi
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "One or more HTTPRoutes have wrong parentRef namespaces!"
  exit 1
else
  echo "All HTTPRoutes are correctly pointing to infra-gateway. ✅"
fi


###
#!/bin/bash
# validate-httproute-full.sh

echo "Checking HTTPRoute parentRefs and backendRefs..."

fail=0

# Pull all current Service names in the cluster
services=$(kubectl get svc -A --no-headers | awk '{print $2 "," $1}')

for file in $(git diff --cached --name-only | grep -E '.*\.yaml$'); do
  if grep -q 'kind: HTTPRoute' "$file"; then
    parent_namespace=$(yq e '.spec.parentRefs[0].namespace' "$file")
    if [[ "$parent_namespace" != "infra-gateway" ]]; then
      echo "ERROR: $file has wrong parentRef namespace: $parent_namespace"
      fail=1
    fi

    backend_service=$(yq e '.spec.rules[0].backendRefs[0].name' "$file")
    backend_namespace=$(yq e '.metadata.namespace' "$file")
    service_key="$backend_service,$backend_namespace"

    if ! echo "$services" | grep -q "$service_key"; then
      echo "ERROR: $file backendRefs points to non-existent Service: $backend_service in namespace $backend_namespace"
      fail=1
    fi
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "One or more HTTPRoutes have wrong parentRefs or invalid backendRefs! ❌"
  exit 1
else
  echo "All HTTPRoutes passed validation. ✅"
fi
