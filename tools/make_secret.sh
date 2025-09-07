#!/bin/bash

# Generate N8N encryption secret
# Usage: ./tools/make_secret.sh [namespace] [secret-name]

NAMESPACE=${1:-n8n}
SECRET_NAME=${2:-n8n-encryption-secret}

echo "Generating encryption key for N8N..."
ENCRYPTION_KEY=$(openssl rand -base64 32)

echo "Creating secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
kubectl create secret generic "$SECRET_NAME" \
  -n "$NAMESPACE" \
  --from-literal=encryption-key="$ENCRYPTION_KEY"

if [ $? -eq 0 ]; then
  echo "✅ Secret '$SECRET_NAME' created successfully!"
  echo "📋 Encryption key: $ENCRYPTION_KEY"
else
  echo "❌ Failed to create secret"
  exit 1
fi