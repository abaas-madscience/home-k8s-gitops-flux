


# Build the image
docker build -t harbor.public.lab.local/home/storage-perf-test:latest .

# Push to Harbor
docker push harbor.public.lab.local/home/storage-perf-test:latest

# Build local

# Test local
docker run --rm -it -v $(pwd)/test-data:/data pvc-perf-test