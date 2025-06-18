

kind create cluster --name testbox --config 3node.yaml 



kubectl config delete-context kind-my-test-cluster

docker network rm kind
