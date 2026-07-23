# Kubernetes Core Concepts Deep Dive

This is the main vendor-neutral Kubernetes study guide for the ReleaseOps lab.
It does not assume that the target company uses EKS. The Kubernetes behavior is
the same whether the cluster runs on AWS, Azure, Google Cloud, OpenShift, or an
on-premises platform. Cloud-specific controllers and storage implementations
change, but the Kubernetes object model and troubleshooting method remain useful.

## First, Be Honest About What Exists

The live `releaseops` namespace currently contains platform guardrails:

- Namespace
- ServiceAccounts
- ResourceQuota
- LimitRange

The application resources are implemented as a Helm reference chart but are not
live-installed. The chart now renders:

- ConfigMap
- Deployment
- Service
- startup, readiness, and liveness probes
- HorizontalPodAutoscaler
- PodDisruptionBudget
- NetworkPolicy
- optional Ingress
- optional Role and RoleBinding

The `k8s/interview-reference` folder adds realistic, non-applied examples for:

- Job and CronJob
- StatefulSet, headless Service, StorageClass, and persistent storage
- DaemonSet
- namespace-scoped support RBAC

Interview-safe wording:

> I applied the Kubernetes namespace guardrails to the live cluster. I also
> built and locally rendered a production-shaped Helm workload chart and
> reference manifests for the broader Kubernetes interview surface. I did not
> claim that every reference workload was live-deployed.

## The One Mental Model That Connects Everything

Kubernetes is a desired-state system.

```text
You submit desired state
        |
        v
API server validates and stores the object
        |
        v
Controllers compare desired state with actual state
        |
        v
Controllers take actions to reduce the difference
        |
        v
Status and events show the observed result
```

For example, you do not normally tell Kubernetes, "start container number 7."
You submit a Deployment saying, "I want three replicas of this Pod template."
The Deployment controller and ReplicaSet controller continuously work toward
three healthy Pods.

This is reconciliation. It is the central idea behind Kubernetes.

Interview answer:

> Kubernetes uses declarative desired state. I submit objects through the API
> server, controllers reconcile actual state toward the desired state, and I use
> status, events, metrics, and logs to verify the outcome.

## Anatomy Of A Kubernetes Object

Most objects contain these fields:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: release-service
  namespace: releaseops
  labels:
    app: release-service
spec:
  replicas: 2
```

- `apiVersion` selects the Kubernetes API group and version.
- `kind` identifies the object type.
- `metadata` gives identity, namespace, labels, annotations, and ownership data.
- `spec` is the desired state supplied by the user.
- `status` is the observed state written by Kubernetes controllers.

Do not put `status` in normal application YAML. Kubernetes owns it.

### Labels, selectors, and annotations

Labels are searchable identity. Selectors use labels to connect objects.

```text
Service selector -> matching Pods
Deployment selector -> matching Pod template
NetworkPolicy podSelector -> protected Pods
PDB selector -> protected Pods
```

Annotations carry non-identifying metadata, such as controller configuration or
a checksum used to trigger a rollout.

Production gotcha:

If a Service selector does not match the Pod labels, the Service exists but has
no endpoints. The application looks deployed, yet traffic goes nowhere.

Useful commands:

```bash
kubectl get pods -n releaseops --show-labels
kubectl get service release-service -n releaseops -o yaml
kubectl get endpointslice -n releaseops -l kubernetes.io/service-name=release-service
```

## Pod

A Pod is Kubernetes' smallest scheduling unit. A Pod can contain one or more
containers that share:

- one network namespace and IP address
- localhost connectivity
- declared volumes
- one scheduling lifecycle

Most application Pods contain one main container. Multiple containers are used
when they must share the same lifecycle and local resources, such as a sidecar
proxy or log helper.

Important: a Pod is replaceable. Its IP and UID can change. Do not use a Pod IP
as a permanent address and do not store durable business data only in the
container filesystem.

Common Pod phases:

- `Pending`: accepted but not fully scheduled or started
- `Running`: at least one container is running or starting
- `Succeeded`: every container completed successfully
- `Failed`: at least one container ended unsuccessfully and will not restart
- `Unknown`: the control plane cannot determine the Pod state

`Running` does not mean `Ready`. A Pod can be running while its readiness probe
fails, so Services should not send it traffic.

Interview answer:

> A Pod is the smallest Kubernetes scheduling unit, not simply another name for
> a container. Containers in a Pod share networking and volumes, and the Pod is
> treated as a replaceable unit.

## ReplicaSet And Deployment

A ReplicaSet maintains a specific number of matching Pods. In normal application
delivery, you do not create ReplicaSets directly. A Deployment creates and owns
them.

```text
Deployment
   |
   +--> ReplicaSet for revision 1 --> Pods
   |
   +--> ReplicaSet for revision 2 --> Pods
```

The Deployment adds rollout history and update strategy. Our chart uses:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
revisionHistoryLimit: 5
```

Meaning:

- `maxUnavailable: 0` asks Kubernetes to keep all desired replicas available
  during rollout.
- `maxSurge: 1` permits one temporary extra Pod.
- `revisionHistoryLimit: 5` keeps enough old ReplicaSets for rollback without
  retaining unlimited history.

The Pod template hash changes when the Pod template changes. Kubernetes creates
a new ReplicaSet and gradually moves replicas to it.

Useful commands:

```bash
kubectl get deployment,replicaset,pod -n releaseops
kubectl rollout status deployment/release-service -n releaseops
kubectl rollout history deployment/release-service -n releaseops
kubectl rollout undo deployment/release-service -n releaseops
```

Production gotchas:

- A bad readiness probe can make a correct rollout appear stuck.
- A broad `maxUnavailable` can reduce capacity during rollout.
- A strict `maxUnavailable: 0` needs spare cluster capacity for the surge Pod.
- Rollback restores the Pod template. It does not automatically reverse a
  destructive database migration.

Interview answer:

> I deploy stateless services through Deployments. A Deployment owns
> ReplicaSets, which own Pods. During a rolling update, readiness determines
> whether new Pods can receive traffic and whether old replicas can be removed.

## ConfigMap And Secret

ConfigMap stores non-secret configuration. Secret stores sensitive data in a
separate Kubernetes object.

Our chart creates a ConfigMap from non-secret Helm values:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: release-service
data:
  SPRING_PROFILES_ACTIVE: "dev"
  DATABASE_HOST: "database.example.internal"
```

The Deployment consumes it with:

```yaml
envFrom:
  - configMapRef:
      name: release-service
```

The database password is read from an existing Secret:

```yaml
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: releaseops-db
        key: password
```

Secret values in YAML are usually base64-encoded, not encrypted merely because
they are base64. Production protection also needs:

- encryption at rest for the Kubernetes datastore
- strict RBAC
- external secret management or a secrets CSI integration
- rotation and access auditing
- avoidance of secrets in Git, logs, command history, and plain Helm values

Environment variables are read at process startup. Updating the ConfigMap or
Secret does not normally restart the Pod. Our chart adds a ConfigMap checksum to
the Pod template, so a ConfigMap change produces a controlled rollout.

Production gotcha:

Mounted ConfigMap and Secret volumes can update eventually, but an application
must reload the file to use the new value. Environment variables do not refresh
inside a running process.

Interview answer:

> I use ConfigMaps for non-secret configuration and Secrets for sensitive
> references. I do not treat base64 as encryption. I also define how workloads
> reload configuration, because changing an object does not guarantee the
> application has consumed the new value.

## Service

Pods are replaceable and their IPs change. A Service gives a stable virtual
address and DNS name for a selected set of ready Pods.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: release-service
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/instance: release-service
  ports:
    - port: 8080
      targetPort: http
```

The important port fields are:

- `port`: the port exposed by the Service
- `targetPort`: the Pod port or named container port receiving traffic
- `containerPort`: documentation and naming on the container; it does not by
  itself publish anything
- `nodePort`: a port opened on every node for a NodePort or LoadBalancer Service

Traffic path:

```text
client Pod
   -> Service DNS name
   -> ClusterIP
   -> EndpointSlice containing ready Pod IPs
   -> selected Pod targetPort
```

Service types:

- `ClusterIP`: internal cluster access; default and most common
- `NodePort`: opens a port on every node; often an implementation detail
- `LoadBalancer`: asks a cloud/controller integration for an external load balancer
- `ExternalName`: DNS alias to an external hostname; no proxying
- headless Service with `clusterIP: None`: returns individual Pod addresses,
  commonly used with StatefulSets

Production gotcha:

A Service routes only to Ready endpoints. If Pods are Running but not Ready,
the Service can have zero usable endpoints.

Interview answer:

> A Service decouples clients from replaceable Pod IPs. Its selector discovers
> matching Pods, EndpointSlices hold the current backends, and only ready
> endpoints normally receive traffic.

## Ingress

Ingress is an HTTP/HTTPS routing object. It defines host and path rules, but the
Ingress object does nothing by itself. An Ingress controller watches it and
implements the routing through a reverse proxy or cloud load balancer.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  ingressClassName: nginx
  rules:
    - host: releases.example.com
      http:
        paths:
          - path: /api/releases
            pathType: Prefix
            backend:
              service:
                name: release-service
                port:
                  number: 8080
```

Full request path:

```text
DNS -> load balancer/controller -> Ingress rule -> Service -> ready Pod
```

Common failures:

- DNS points to the wrong load balancer
- no Ingress controller exists
- wrong `ingressClassName`
- host or path does not match
- backend Service has no endpoints
- TLS certificate or secret is wrong
- controller lacks permission or cloud configuration

The chart keeps Ingress disabled because creating a cloud load balancer can add
cost. This is a conscious lab decision, not a missing concept.

## Probes

Kubernetes has three different health questions.

### Startup probe

Question: has this slow-starting process finished booting?

While startup fails, liveness and readiness are not used. This protects a Java
application from being killed merely because startup takes time.

### Readiness probe

Question: should this Pod receive traffic now?

Failure removes the Pod from Service endpoints but does not restart it.

### Liveness probe

Question: is this process stuck and should kubelet restart the container?

Failure causes a restart. A liveness endpoint should not depend on every remote
system. If database slowness makes liveness fail, Kubernetes can restart every
healthy application replica and create a larger outage.

Probe flow in our chart:

```yaml
startupProbe:
  httpGet:
    path: /actuator/health/liveness
    port: http
  failureThreshold: 30
  periodSeconds: 5
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: http
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: http
```

Production gotchas:

- Probe path or port typo can break every rollout.
- Aggressive liveness thresholds create restart loops.
- Readiness that always returns success sends traffic too early.
- A startup probe does not fix an application that never becomes healthy.

## Requests, Limits, QoS, And Scheduling

Requests and limits solve different problems.

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Request:

- used by the scheduler when selecting a node
- represents reserved scheduling capacity
- becomes the denominator for CPU-utilization HPA calculations

Limit:

- enforced at runtime through container resource controls
- CPU overuse is normally throttled
- memory overuse can cause `OOMKilled`

`100m` CPU means one tenth of a CPU core. `256Mi` is 256 mebibytes.

QoS classes:

- `Guaranteed`: every container has equal CPU and memory requests and limits
- `Burstable`: at least one request/limit exists, but the Guaranteed rule is not met
- `BestEffort`: no requests or limits

Under node memory pressure, lower-priority and lower-QoS Pods are generally more
vulnerable to eviction.

Production gotchas:

- Requests that are too high waste schedulable capacity and cause Pending Pods.
- Requests that are too low create noisy-neighbor behavior and misleading HPA
  percentages.
- Memory limits that are too low cause restarts.
- CPU limits that are too low can create latency through throttling even when
  average CPU looks acceptable.

## LimitRange And ResourceQuota

LimitRange controls defaults, minimums, and maximums for individual containers
or Pods. ResourceQuota controls aggregate namespace consumption.

```text
LimitRange    = per-container guardrail
ResourceQuota = whole-namespace budget
```

Our live namespace has both.

Example failure:

```text
Forbidden: exceeded quota
```

This can happen at admission time before any Pod is created. Check:

```bash
kubectl describe resourcequota releaseops-compute-quota -n releaseops
kubectl describe limitrange releaseops-default-container-limits -n releaseops
```

## ServiceAccount And RBAC

A ServiceAccount is a workload identity inside Kubernetes. RBAC decides what an
identity may do through the Kubernetes API.

RBAC building blocks:

- `Role`: permissions inside one namespace
- `ClusterRole`: cluster-scoped permissions or a reusable permission set
- `RoleBinding`: grants a Role or ClusterRole inside one namespace
- `ClusterRoleBinding`: grants cluster-wide access

Reference read-only Role:

```yaml
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "events"]
    verbs: ["get", "list", "watch"]
```

This separates resource from action:

```text
resource = pods/log
verb     = get
```

Check authorization without guessing:

```bash
kubectl auth can-i get pods -n releaseops
kubectl auth can-i get pods/log -n releaseops
kubectl auth can-i delete deployments -n releaseops
```

Our application Pods default to `automountServiceAccountToken: false`. A Pod
that does not call the Kubernetes API does not need a token mounted. Enable it
only when a proven workload or cloud-identity integration requires it.

Production gotcha:

Do not give an application `cluster-admin` to solve a `Forbidden` error. Read the
error, identify the exact API group, resource, verb, and namespace, then grant
the smallest permission.

## Security Context

Our container baseline includes:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities:
    drop: ["ALL"]
```

The Pod also uses:

```yaml
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

These controls reduce what a compromised process can do. The application gets a
writable `emptyDir` at `/tmp` because a read-only root filesystem otherwise
breaks software that legitimately writes temporary files.

Production gotcha:

Security settings must be tested with the real image. `runAsNonRoot` can fail if
the image declares a numeric root user, and `readOnlyRootFilesystem` can expose
hidden write assumptions during startup.

## NetworkPolicy

NetworkPolicy is a Pod-level traffic policy. By default, Kubernetes networking
is usually allow-all. A Pod becomes isolated for a direction when a matching
NetworkPolicy selects it for that direction.

Our chart selects one release and defines explicit ingress and egress:

```yaml
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: release-service
  policyTypes: ["Ingress", "Egress"]
```

Important rules:

- `podSelector: {}` selects every Pod in the policy namespace.
- An empty `ingress: []` denies all ingress to selected Pods.
- An empty `egress: []` denies all egress from selected Pods.
- Multiple policies are additive. One policy does not override another.
- Both source egress and destination ingress must allow a connection when both
  sides are isolated.
- The network plugin must implement NetworkPolicy. The API object alone does not
  guarantee enforcement.

DNS is easy to forget. A default-deny egress policy can break name resolution
before the application even attempts its database connection. Our chart
explicitly permits TCP and UDP port 53 to DNS Pods.

Standard NetworkPolicy selects Pods, namespaces, and IP blocks. It does not
natively allow an external destination by DNS name. External RDS or SaaS access
therefore needs careful CIDR, egress gateway, firewall, service mesh, or
plugin-specific policy design.

Interview answer:

> I start from default deny and add the minimum application flows, including
> DNS. I also verify that the cluster CNI enforces NetworkPolicy, because a valid
> object that is not enforced creates false confidence.

## HorizontalPodAutoscaler

HPA changes replica count based on observed metrics.

```yaml
minReplicas: 2
maxReplicas: 5
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

For CPU utilization, the simplified calculation is:

```text
desired replicas = current replicas x current utilization / target utilization
```

Kubernetes rounds appropriately and applies tolerance and behavior rules.

Requirements:

- a working metrics source, commonly Metrics Server for CPU/memory
- CPU requests on Pods for CPU utilization targets
- enough node capacity to schedule new Pods

Our chart omits `Deployment.spec.replicas` when HPA is enabled. Otherwise HPA,
Helm, or GitOps reconciliation can fight over replica count.

HPA scales Pods. It does not create nodes. If extra replicas are Pending because
the cluster is full, a separate node autoscaler is needed.

Production gotcha:

CPU may be the wrong business signal. Queue workers often scale better on queue
depth or message age, while APIs may use request rate or latency.

## PodDisruptionBudget

PDB limits how many selected Pods may be unavailable during voluntary
disruptions such as node drain.

```yaml
spec:
  minAvailable: 1
```

PDB does not protect against:

- node crash
- process crash
- application bug
- network partition
- involuntary infrastructure failure

It also does not create replicas. A PDB with `minAvailable: 1` and one replica
can block a node drain indefinitely. That is why replica count and PDB must be
designed together.

Interview answer:

> A PDB protects availability during voluntary eviction, not every failure. I
> size it with the replica count and rollout or maintenance strategy so it does
> not block legitimate operations.

## Scheduling Controls

### nodeSelector

Simple hard requirement based on node labels. If no node matches, the Pod stays
Pending.

### Node affinity

More expressive node selection with required or preferred rules.

### Pod anti-affinity

Tries to keep replicas away from each other based on Pod labels. Our chart uses
soft anti-affinity across hostnames, so replicas prefer different nodes but can
still schedule in the one-node lab.

### Topology spread constraints

Controls skew across topology domains such as hostname or zone. Our chart uses
`ScheduleAnyway` because strict zone spreading would make replicas Pending in a
cost-controlled single-node cluster.

### Taints and tolerations

A taint repels Pods. A toleration permits a matching Pod to be considered for
that node, but does not force it there.

```text
taint      = keep ordinary Pods away
toleration = this Pod is allowed past that restriction
affinity   = choose or prefer a placement
```

Production gotcha:

Required anti-affinity across zones can make a deployment unschedulable when an
AZ is unavailable. Reliability constraints must account for degraded operation.

## Job And CronJob

Job runs finite work to completion. CronJob creates Jobs on a schedule.

ReleaseOps examples:

- Flyway migration Job before application rollout
- scheduled stale-release report CronJob

Important Job fields:

- `restartPolicy: Never` or `OnFailure`
- `backoffLimit`: retries before the Job is failed
- `activeDeadlineSeconds`: maximum runtime
- `ttlSecondsAfterFinished`: cleanup of finished Job objects

Important CronJob fields:

- `schedule`
- `timeZone`
- `concurrencyPolicy: Forbid` to prevent overlapping runs
- `startingDeadlineSeconds` for missed schedules
- history limits

Production gotcha:

A Job retry can repeat work. Migration and cleanup logic must be idempotent or
must use locking. `concurrencyPolicy: Forbid` prevents overlap but does not make
the business operation safe by itself.

## StatefulSet, PV, PVC, And StorageClass

StatefulSet is for workloads that need stable identity, ordered behavior, or
stable per-replica storage.

```text
metrics-store-0
metrics-store-1
metrics-store-2
```

Unlike randomly named Deployment Pods, StatefulSet Pods keep predictable
ordinals. A headless Service provides DNS identities for individual Pods.

Storage objects:

- `StorageClass`: how dynamic storage should be provisioned
- `PersistentVolume`: cluster storage resource
- `PersistentVolumeClaim`: workload request for storage
- `volumeClaimTemplates`: one PVC template per StatefulSet replica

Binding flow:

```text
Pod references PVC
  -> PVC requests a StorageClass
  -> CSI provisioner creates storage
  -> PV represents that storage
  -> PVC binds to the PV
  -> volume attaches and mounts to the node/Pod
```

`WaitForFirstConsumer` delays provisioning until Kubernetes knows the Pod's
placement. This avoids creating zone-bound storage in the wrong zone.

Production gotchas:

- Deleting a StatefulSet does not necessarily delete its PVCs.
- `ReadWriteOnce` normally limits a volume to one node at a time, not one Pod in
  every possible interpretation.
- A volume attached in one zone cannot simply mount on a node in another zone.
- Reclaim policy determines what happens after claim deletion.
- Backups and application-level recovery are still required. A PVC is not a backup.

ReleaseOps keeps its business PostgreSQL database outside Kubernetes on managed
RDS. The StatefulSet example exists for learning and observability storage, not
because every stateful system belongs inside Kubernetes.

## DaemonSet

DaemonSet runs one Pod on every eligible node, or every node matching its
placement rules.

Typical uses:

- log collectors
- node monitoring agents
- security agents
- networking components
- storage node plugins

When a new node joins, the DaemonSet controller creates an agent Pod there. When
the node is removed, that Pod disappears with it.

Production gotcha:

A DaemonSet consumes resources on every node. A small memory leak multiplied by
hundreds of nodes becomes a major incident. Tolerations and host access should
be narrowly designed because node agents often receive elevated access.

## Namespace

Namespace provides a logical scope for names and namespaced policy. It is useful
for team, application, environment, or platform separation.

Namespace alone is not a complete security boundary. Combine it with:

- RBAC
- ResourceQuota and LimitRange
- NetworkPolicy
- Pod Security Admission
- admission policies
- separate cloud identities and secrets

Use separate clusters or accounts when the threat model or blast radius requires
stronger isolation than a namespace can provide.

## The Core Interview Comparison Table

| Question | Correct distinction |
|---|---|
| Pod vs Deployment | Pod runs containers; Deployment manages rolling, replicated Pods through ReplicaSets |
| Deployment vs StatefulSet | Deployment gives replaceable replicas; StatefulSet gives stable identity and storage patterns |
| Deployment vs DaemonSet | Deployment targets a replica count; DaemonSet targets eligible nodes |
| Job vs Deployment | Job finishes; Deployment continuously maintains running replicas |
| Service vs Ingress | Service exposes Pods through a stable endpoint; Ingress routes external HTTP(S) to Services |
| ConfigMap vs Secret | Both provide configuration; Secret is separately handled sensitive data, but base64 is not encryption |
| Request vs limit | Request drives scheduling; limit caps runtime use |
| LimitRange vs ResourceQuota | LimitRange is per-container/Pod policy; ResourceQuota is namespace aggregate budget |
| HPA vs node autoscaler | HPA changes Pod count; node autoscaler changes node capacity |
| Readiness vs liveness | Readiness controls traffic; liveness controls restart |
| Role vs ClusterRole | Role is namespace-scoped; ClusterRole is cluster-scoped or reusable across namespaces |
| PDB vs replicas | Replicas create capacity; PDB limits voluntary eviction |

## Study Order

Study this guide in four passes:

1. Object model, Pod, Deployment, ConfigMap, Secret, Service, and probes.
2. Requests/limits, scheduling, HPA, PDB, and namespace guardrails.
3. ServiceAccount, RBAC, security context, NetworkPolicy, and Ingress.
4. Job, CronJob, StatefulSet/storage, and DaemonSet.

After each pass, use `docs/23-kubernetes-troubleshooting-playbook.md` to connect
the concepts to symptoms and commands.
