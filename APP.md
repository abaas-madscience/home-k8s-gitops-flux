---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: <appname>-gateway
  namespace: <namespace>
spec:
  gatewayClassName: cilium
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: wildcard-tls
      allowedRoutes:
        namespaces:
          from: Same

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <appname>-httproute
  namespace: <namespace>
spec:
  parentRefs:
    - name: <appname>-gateway
  hostnames:
    - "<your-app-.public.lab.local>"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: <appname>
          port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: <appname>
  namespace: <namespace>
spec:
  type: ClusterIP
  selector:
    app: <appname>
  ports:
    - port: 80
      targetPort: 80

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <appname>
  namespace: <namespace>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <appname>
  template:
    metadata:
      labels:
        app: <appname>
    spec:
      containers:
        - name: <appname>
          image: <your-image>
          ports:
            - containerPort: 80
