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
            name: <appname>-tls
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
    - "<your-app-domain.lab.local>"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: <appname>
          port: 80
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: <appname>-tls
  namespace: <namespace>
spec:
  secretName: <appname>-tls
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  commonName: <your-app-domain.lab.local>
  dnsNames:
    - <your-app-domain.lab.local>
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
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
