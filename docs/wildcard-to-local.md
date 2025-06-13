

kubectl get secret infra-gateway-wildcard-tls -n cilium-secrets -o jsonpath='{.data.tls\.crt}' | base64 -d > harbor.lab.local.crt                     


Harbor

echo -e 'FROM alpine\nCMD ["echo", "Hello from Harbor"]' > Dockerfile
docker build -t harbor.public.lab.local/home/hello-harbor:latest .


docker push harbor.public.lab.local/home/hello-harbor:latest

