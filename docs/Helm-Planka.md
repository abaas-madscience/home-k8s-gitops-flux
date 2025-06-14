That's an excellent plan! Building your own Helm chart for Planka will give you a deep understanding of Kubernetes deployment and Helm itself, and using Harbor to host it is the perfect final step for a private, versioned chart repository.

Let's break down the process step-by-step.
Part 1: Understanding Planka's Requirements

Before creating a Helm chart, we need to understand what Planka needs to run.
From the search results, we know:

    Docker Image: Planka is available as a Docker image, typically lscr.io/linuxserver/planka or ghcr.io/plankanban/planka.

Database: Planka requires a PostgreSQL database.
Environment Variables: It's configured via environment variables, some of the key ones being:

    DATABASE_URL: Connection string for PostgreSQL (e.g., postgresql://user:password@host:port/database).

SECRET_KEY: A strong, randomly generated key for session encryption.
BASE_URL: The URL where Planka will be accessible (e.g., https://planka.example.com).
DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_USERNAME, DEFAULT_ADMIN_PASSWORD, DEFAULT_ADMIN_NAME: For initial admin user creation. These should ideally be set once for a new instance, then removed or managed differently.

Persistent Storage: Planka stores user avatars, project background images, and attachments. This data needs to persist even if the Planka pod restarts. This usually means mounting a PersistentVolume.

    Port: Planka typically listens on port 1337.

Part 2: Building Your First Helm Chart for Planka

Helm charts have a standard structure. Let's create one.

Prerequisites:

    helm CLI installed (Helm 3 recommended).
    kubectl configured to interact with your Kubernetes cluster.

Step-by-Step Chart Creation:

    Create the Chart Skeleton:
    Open your terminal and run:
    Bash

helm create planka-board
cd planka-board

This command generates a basic Helm chart structure:

planka-board/
├── Chart.yaml
├── charts/
├── templates/
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   └── serviceaccount.yaml
└── values.yaml

Edit Chart.yaml:
This file contains metadata about your chart. Open Chart.yaml and update it.
YAML

apiVersion: v2
name: planka-board
description: A Helm chart for deploying Planka Kanban board.
type: application
version: 0.1.0 # Your chart version
appVersion: "latest" # The version of Planka you intend to deploy (e.g., "2.0.0" or "latest")

# Add dependencies for PostgreSQL
dependencies:
  - name: postgresql
    version: "15.0.0" # Use a stable version from Bitnami or similar
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled # Only include if postgresql is enabled

Explanation:

    apiVersion: Specifies the Helm API version.

name, description, type: Self-explanatory.
version: Your chart's version. Increment this when you make changes to your chart.
appVersion: The version of the application (Planka) that this chart is designed to deploy.
dependencies: This is crucial! We'll use a public Helm chart for PostgreSQL to simplify database deployment. Bitnami provides excellent, well-maintained charts. The condition ensures PostgreSQL is only deployed if enabled in values.yaml.

Configure values.yaml:
This file defines the default configuration values for your chart. We'll modify it to suit Planka and its PostgreSQL dependency.
YAML

replicaCount: 1

image:
  repository: lscr.io/linuxserver/planka # Or ghcr.io/plankanban/planka
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: "latest" # Ensure this matches your desired Planka version

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""

podAnnotations: {}
podSecurityContext: {}
  # fsGroup: 2000

securityContext: {}
  # capabilities:
  #   drop:
  #   - ALL
  # readOnlyRootFilesystem: true
  # runAsNonRoot: true
  # runAsUser: 1000

service:
  type: ClusterIP
  port: 1337 # Planka's default port

ingress:
  enabled: false # Set to true to enable Ingress for external access
  className: ""
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  hosts:
    - host: planka.local # Change this to your desired domain
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

resources: {}
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts will run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # and adjust as necessary.
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}

# Planka specific configurations
planka:
  secretKey: "CHANGE_ME_TO_A_STRONG_RANDOM_KEY" # Generate this securely, e.g., openssl rand -hex 32
  baseUrl: "http://planka.local" # Change this to your accessible URL

  admin: # Only for initial deployment; can be commented out after first run
    email: "admin@example.com"
    username: "admin"
    password: "changeme"
    name: "Planka Admin"

  persistence:
    enabled: true
    storageClass: "" # Optional: Specify your storage class, e.g., "nfs-client"
    size: 5Gi # Adjust as needed for avatars, attachments etc.

# PostgreSQL database configuration (dependency)
postgresql:
  enabled: true
  auth:
    database: planka
    username: planka_user
    password: "a_strong_db_password" # CHANGE THIS!
  primary:
    persistence:
      enabled: true
      storageClass: "" # Optional: Specify your storage class
      size: 8Gi # Adjust for your expected database size

Key modifications in values.yaml:

    image.repository, image.tag: Set to Planka's Docker image.
    service.port: Changed to 1337.
    ingress.enabled, ingress.hosts: Set enabled: true and configure hosts if you want external access. Remember to set up an Ingress Controller (like Nginx Ingress Controller) in your cluster.
    planka: A new section for Planka-specific environment variables.
        secretKey: Crucial! Generate a long, random hexadecimal string (e.g., openssl rand -hex 32 or openssl rand -hex 64). Never use the default in production.

        baseUrl: The URL where Planka will be accessed.
        admin: Initial admin user details. It's often recommended to remove or comment these out after the first successful deployment to prevent overwriting changes.
        persistence: Configuration for Planka's persistent storage for files.
    postgresql: This section configures the Bitnami PostgreSQL sub-chart.
        enabled: true: Ensures the PostgreSQL chart is deployed.
        auth.database, auth.username, auth.password: Database credentials for Planka to connect. Use a strong password!
        primary.persistence: Enable and configure persistent storage for the database.

Modify templates/deployment.yaml:
This is where we define the Kubernetes Deployment for Planka.

    Image and Ports: Ensure the image uses {{ .Values.image.repository }}:{{ .Values.image.tag }} and the container port is 1337.
    Environment Variables: Map the planka values from values.yaml to environment variables for the Planka container.
    Database URL: Construct the DATABASE_URL environment variable using the PostgreSQL sub-chart's service name.
    Volume Mounts and Persistent Volume Claim: Add a volume mount for Planka's data and a corresponding PersistentVolumeClaim.

Here's a simplified example of relevant parts of templates/deployment.yaml. You'll need to integrate these into the existing template:
YAML

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "planka-board.fullname" . }}
  labels:
    {{- include "planka-board.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "planka-board.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "planka-board.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "planka-board.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 16 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 1337 # Planka's port
              protocol: TCP
          env:
            - name: BASE_URL
              value: {{ .Values.planka.baseUrl | quote }}
            - name: SECRET_KEY
              value: {{ .Values.planka.secretKey | quote }}
            - name: DATABASE_URL
              value: "postgresql://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ include "planka-board.fullname" . }}-postgresql:5432/{{ .Values.postgresql.auth.database }}"
            {{- if .Values.planka.admin.email }}
            - name: DEFAULT_ADMIN_EMAIL
              value: {{ .Values.planka.admin.email | quote }}
            - name: DEFAULT_ADMIN_USERNAME
              value: {{ .Values.planka.admin.username | quote }}
            - name: DEFAULT_ADMIN_PASSWORD
              value: {{ .Values.planka.admin.password | quote }}
            - name: DEFAULT_ADMIN_NAME
              value: {{ .Values.planka.admin.name | quote }}
            {{- end }}
            # Add other environment variables as needed based on Planka docs
          volumeMounts:
            - name: planka-data
              mountPath: /config # Default path for linuxserver/planka config
          resources:
            {{- toYaml .Values.resources | nindent 16 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        - name: planka-data
          persistentVolumeClaim:
            claimName: {{ include "planka-board.fullname" . }}-data

Modify templates/service.yaml:
Ensure the service exposes port 1337.
YAML

apiVersion: v1
kind: Service
metadata:
  name: {{ include "planka-board.fullname" . }}
  labels:
    {{- include "planka-board.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "planka-board.selectorLabels" . | nindent 8 }}

Create templates/pvc.yaml (for Planka data):
You'll need a PersistentVolumeClaim for Planka's user avatars, attachments, etc.
YAML

{{- if .Values.planka.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "planka-board.fullname" . }}-data
  labels:
    {{- include "planka-board.labels" . | nindent 4 }}
  {{- with .Values.planka.persistence.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  accessModes:
    - ReadWriteOnce # Usually sufficient for a single-pod application
  resources:
    requests:
      storage: {{ .Values.planka.persistence.size }}
  {{- if .Values.planka.persistence.storageClass }}
  storageClassName: {{ .Values.planka.persistence.storageClass }}
  {{- end }}
{{- end }}

Modify templates/ingress.yaml (if enabling Ingress):
Uncomment and adapt the ingress.yaml template if you set ingress.enabled: true in values.yaml.
YAML

{{- if .Values.ingress.enabled -}}
{{- $fullName := include "planka-board.fullname" . -}}
{{- $svcPort := .Values.service.port -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 8 }}
  {{- end }}
  labels:
    {{- include "planka-board.labels" . | nindent 4 }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}

Test Your Chart (Local Installation):
Before pushing to Harbor, test it locally.

    Update Dependencies:
    Bash

helm dependency update ./planka-board

This will download the PostgreSQL chart into planka-board/charts/.

Dry Run (Important for debugging):
Bash

helm install my-planka ./planka-board --dry-run --debug

This will show you the YAML Kubernetes manifests that Helm would generate without actually deploying them. Check for errors, especially in environment variables and volume definitions.

Install:
First, generate a strong SECRET_KEY.
Bash

export PLANKA_SECRET_KEY=$(openssl rand -hex 64)

Now install, overriding the secretKey and database password:
Bash

helm install my-planka ./planka-board \
  --set planka.secretKey=$PLANKA_SECRET_KEY \
  --set postgresql.auth.password="your_secure_db_password_here" \
  --set planka.baseUrl="http://your-planka-ip-or-domain" \
  --create-namespace --namespace planka

Note: For planka.baseUrl, if you're just testing with ClusterIP service, you might not have an easy external URL initially. You'd typically use kubectl port-forward to access it. If using Ingress, set planka.baseUrl to your Ingress host.

Check Deployment:
Bash

kubectl get pods -n planka
kubectl get svc -n planka
kubectl get pvc -n planka
kubectl get ingress -n planka # If enabled

Wait for pods to be Running. You should see my-planka-planka-board-... for Planka and my-planka-postgresql-... for the database.

Access Planka (if no Ingress):
Find the Planka pod name:
Bash

kubectl get pods -n planka -l app.kubernetes.io/name=planka-board -o jsonpath='{.items[0].metadata.name}'

Then port-forward:
Bash

kubectl port-forward <planka-pod-name> 8080:1337 -n planka

Now you can access Planka at http://localhost:8080 in your browser.

Uninstall:
Bash

        helm uninstall my-planka -n planka

Part 3: Hosting Your Helm Chart in Harbor

Harbor acts as both a Docker image registry and a Helm chart repository. This is super convenient!

Prerequisites:

    Harbor instance up and running.
    You have an existing project in Harbor or create a new one (e.g., my-apps).
    helm-push plugin installed:
    Bash

    helm plugin install https://github.com/chartmuseum/helm-push

Step-by-Step Harbor Integration:

    Log in to Harbor CLI (Docker & Helm):
    First, ensure you can log in to your Harbor Docker registry for image pushes (though we're using a public Planka image, this is good practice).
    Bash

docker login your-harbor-domain.com

Enter your Harbor username and password.

For Helm, you'll add Harbor as a repository. Harbor supports both ChartMuseum (legacy Helm 2 style) and OCI-based registries (modern Helm 3 style, where charts are treated like OCI artifacts, similar to Docker images). It's highly recommended to use the OCI-based registry for Helm 3.

To log in to the OCI registry of Harbor:
Bash

helm registry login your-harbor-domain.com -u <your_harbor_username> -p <your_harbor_password>

Package Your Helm Chart:
Go back to the root of your planka-board chart directory (where Chart.yaml is).
Bash

helm package .

This will create a .tgz archive of your chart, e.g., planka-board-0.1.0.tgz.

Push Your Chart to Harbor (OCI Method):
Now, push the packaged chart to your Harbor OCI registry. Replace your-harbor-domain.com and my-apps with your actual values.
Bash

helm push planka-board-0.1.0.tgz oci://your-harbor-domain.com/my-apps

This command pushes planka-board-0.1.0.tgz to the my-apps project in your Harbor OCI registry.

If your Harbor is older and doesn't support OCI for Helm charts, or you prefer the ChartMuseum way (less recommended for Helm 3):

    Add the repository:
    Bash

helm repo add my-harbor-charts https://your-harbor-domain.com/chartrepo/<your_harbor_project_name> --username <your_harbor_username> --password <your_harbor_password>

Push with helm-push plugin:
Bash

    helm push planka-board-0.1.0.tgz my-harbor-charts

Verify in Harbor UI:
Log into your Harbor web interface. Navigate to your project (my-apps).

    If using OCI: You should see your planka-board chart listed under "Artifacts" alongside any Docker images. It will have a type of "Helm Chart".
    If using ChartMuseum: You'll find a dedicated "Helm Charts" tab where your chart should appear.

Install from Harbor:
Now, from any Kubernetes cluster (that can access your Harbor), you can install your chart.

    For OCI (Helm 3.8+):
    You don't explicitly helm repo add for OCI. You directly reference the OCI URL.
    Bash

export PLANKA_SECRET_KEY=$(openssl rand -hex 64)
helm install my-planka oci://your-harbor-domain.com/my-apps/planka-board --version 0.1.0 \
  --set planka.secretKey=$PLANKA_SECRET_KEY \
  --set postgresql.auth.password="your_secure_db_password_here" \
  --set planka.baseUrl="http://your-planka-ip-or-domain" \
  --create-namespace --namespace planka

(Remember to helm registry login your-harbor-domain.com first if authentication is required).

For ChartMuseum (less common for Helm 3 anymore):
Bash

        helm repo update # To fetch the latest chart index from Harbor
        helm install my-planka my-harbor-charts/planka-board --version 0.1.0 \
          --set planka.secretKey=$PLANKA_SECRET_KEY \
          --set postgresql.auth.password="your_secure_db_password_here" \
          --set planka.baseUrl="http://your-planka-ip-or-domain" \
          --create-namespace --namespace planka

Key Takeaways and Best Practices:

    Templating Power: Helm allows you to template almost anything in your Kubernetes manifests, making your deployments dynamic and reusable.

values.yaml: This is your primary configuration interface for the chart. Keep it well-documented.
Dependencies: For applications with multiple components (like app + database), using sub-charts (like Bitnami's PostgreSQL) is a powerful way to manage complex deployments.
Persistence: Always ensure your application data and database data are on PersistentVolumes.
Secrets: Never hardcode sensitive information like SECRET_KEY or database passwords directly in values.yaml for production. Use Kubernetes Secrets or a secret management solution like HashiCorp Vault. For initial testing, passing them via --set is acceptable.
Ingress: Essential for exposing your application externally with a domain name and typically TLS.
CI/CD: Once you have a working Helm chart, integrate helm lint, helm package, and helm push into your CI/CD pipeline to automate chart packaging and publication to Harbor.
Version Control: Store your Helm chart code in a Git repository.
Iteration: Building a Helm chart is often an iterative process. Start simple, test, and then add more features and configurations as needed.

This detailed walkthrough should set you up nicely for creating your Planka Helm chart and managing it with Harbor. Enjoy the process of mastering Helm!