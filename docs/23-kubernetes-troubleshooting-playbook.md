# Kubernetes Troubleshooting Playbook

This guide is organized around symptoms. The goal is not to memorize random
commands. The goal is to identify the failing layer, collect evidence, and make
the smallest safe correction.

## The Troubleshooting Method

Use this sequence in interviews and real incidents:

```text
1. State the symptom precisely.
2. Check recent change and blast radius.
3. Identify the likely layer.
4. Collect evidence from status, events, logs, metrics, and configuration.
5. Form one testable hypothesis.
6. Apply the smallest reversible fix.
7. Verify service recovery.
8. Prevent recurrence with code, tests, alerts, or policy.
```

Strong interview opening:

> I would first confirm scope and recent changes, then move from Kubernetes
> status and events to container logs, networking, dependencies, and node health.
> I avoid changing several things at once because that destroys diagnostic
> evidence.

## First Five Commands

```bash
kubectl get pods -n releaseops -o wide
kubectl describe pod <pod-name> -n releaseops
kubectl logs <pod-name> -n releaseops --all-containers
kubectl logs <pod-name> -n releaseops --all-containers --previous
kubectl get events -n releaseops --sort-by=.metadata.creationTimestamp
```

What each gives you:

- `get`: current state, readiness, restarts, node, and IP
- `describe`: conditions and events such as scheduling, mount, probe, and image errors
- current logs: what the running process says
- previous logs: why the previous container instance crashed
- events: chronological control-plane and kubelet observations

Events are useful but expire. Logs also disappear when Pods are deleted unless a
central logging system collects them.

## Quick Symptom Map

| Symptom | First layer to inspect |
|---|---|
| Pod Pending | scheduler, quota, placement, or PVC |
| ContainerCreating | image, volume mount, CNI, or runtime |
| ImagePullBackOff | image reference, registry auth, network, or architecture |
| CrashLoopBackOff | process startup, configuration, dependency, or liveness |
| Running but 0/1 Ready | readiness probe or dependency health |
| OOMKilled | memory limit, leak, JVM sizing, or traffic spike |
| Evicted | node pressure or ephemeral storage |
| Service has no endpoints | selector mismatch or no Ready Pods |
| DNS fails | CoreDNS/service DNS/NetworkPolicy |
| Ingress 404 | host/path/class/controller routing |
| Ingress 502/503 | backend Service, endpoints, port, or readiness |
| HPA shows unknown | metrics source or missing requests |
| PVC Pending | StorageClass, CSI, zone, access mode, or capacity |
| Forbidden | RBAC identity, verb, resource, or namespace |
| Drain blocked | PDB or non-evictable workload |

## Scenario 1: Pod Stays Pending

Pending means the Pod has not reached a running container. Do not start with
application logs because the application may not have started.

```bash
kubectl describe pod <pod-name> -n releaseops
kubectl get nodes
kubectl describe node <node-name>
kubectl describe resourcequota -n releaseops
kubectl get pvc -n releaseops
```

Common event messages and meanings:

- `Insufficient cpu`: requests do not fit on any eligible node
- `Insufficient memory`: requested memory does not fit
- `had untolerated taint`: Pod lacks a matching toleration
- `didn't match Pod's node affinity`: placement rules exclude nodes
- `unbound immediate PersistentVolumeClaims`: storage is not bound
- quota error during creation: namespace budget rejected the object

Safe fixes depend on evidence:

- right-size requests
- add capacity
- correct labels, affinity, or tolerations
- correct StorageClass/PVC configuration
- increase quota only after confirming the namespace should receive more budget

Production prevention:

- capacity alerts
- deployment preflight checks
- sane LimitRange defaults
- scheduling policy review
- autoscaling with tested upper bounds

## Scenario 2: ImagePullBackOff

Kubelet cannot pull the image and increases the delay between retries.

```bash
kubectl describe pod <pod-name> -n releaseops
kubectl get pod <pod-name> -n releaseops -o jsonpath='{.spec.containers[*].image}'
kubectl get serviceaccount <service-account> -n releaseops -o yaml
```

Likely causes:

- repository or tag does not exist
- digest is wrong
- private registry authentication is missing
- node or runtime cannot reach the registry
- registry rate limit
- image architecture does not match the node architecture

Do not fix this by changing `imagePullPolicy` blindly. If the image reference is
wrong, pulling more often will not help.

Production prevention:

- immutable image tags or digests
- CI verification that the pushed digest exists
- admission policy restricting allowed registries
- deployment promotion using the exact tested digest

Interview answer:

> I inspect Pod events for the registry response, verify the exact image digest,
> then check registry credentials and node egress. I prefer immutable digests so
> a working artifact cannot silently change under the same tag.

## Scenario 3: CrashLoopBackOff

CrashLoopBackOff means a container starts, exits, and Kubernetes backs off before
restarting it.

```bash
kubectl logs <pod-name> -n releaseops --previous
kubectl describe pod <pod-name> -n releaseops
kubectl get pod <pod-name> -n releaseops -o jsonpath='{.status.containerStatuses[*].lastState}'
```

Common causes:

- invalid command or arguments
- missing environment variable or Secret key
- database connection rejected
- migration failure
- application exits after configuration validation
- liveness probe repeatedly kills a running process
- memory limit causes OOM termination
- read-only filesystem blocks an unexpected write

The `--previous` log is critical because the currently starting container may
not yet contain the failure from the last restart.

Production gotcha:

Increasing liveness delays can hide an application crash but cannot fix it.
Separate process-exit failures from probe-triggered restarts using last state and
events.

## Scenario 4: Pod Is Running But Not Ready

This is not the same as CrashLoopBackOff. The process is alive, but Kubernetes is
withholding it from Service traffic.

```bash
kubectl describe pod <pod-name> -n releaseops
kubectl get pod <pod-name> -n releaseops -o jsonpath='{.status.conditions}'
kubectl logs <pod-name> -n releaseops
kubectl exec -n releaseops <pod-name> -- wget -qO- http://127.0.0.1:8080/actuator/health/readiness
```

Check:

- readiness path and port
- application bind address
- dependency health included in readiness
- timeout and threshold values
- NetworkPolicy or service-mesh interception

If every replica becomes unready, the Service can have zero endpoints even
though every Pod phase says Running.

## Scenario 5: Startup Probe Never Succeeds

```bash
kubectl describe pod <pod-name> -n releaseops
kubectl logs <pod-name> -n releaseops
```

Calculate the maximum startup allowance:

```text
failureThreshold x periodSeconds
```

Our reference values allow roughly `30 x 5 = 150` seconds before startup is
considered failed.

Check whether the process is genuinely making progress. Increasing the window is
reasonable for a known slow start, but dangerous when it merely delays detection
of a deadlocked or permanently misconfigured process.

## Scenario 6: OOMKilled

```bash
kubectl describe pod <pod-name> -n releaseops
kubectl get pod <pod-name> -n releaseops -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'
kubectl top pod <pod-name> -n releaseops --containers
```

Possible causes:

- real memory leak
- workload spike
- heap plus non-heap exceeds the container limit
- JVM sizing ignores container memory budget
- sidecar consumption was forgotten
- limit is simply unrealistic

Do not only raise the limit. First compare normal usage, peak usage, garbage
collection, heap settings, and node capacity. Raising every limit can move the
problem from one Pod to node-level memory pressure.

## Scenario 7: CPU Throttling And High Latency

The Pod may remain Running and Ready while latency grows.

Evidence can include:

- CPU usage near limit
- container throttling metrics
- rising request latency
- healthy memory and no restart

Check the application profile before removing CPU limits. Options include
right-sizing, scaling replicas, changing HPA targets, or tuning application
concurrency. Average CPU alone may hide short bursts.

## Scenario 8: Service Has No Endpoints

```bash
kubectl get service release-service -n releaseops -o yaml
kubectl get pods -n releaseops --show-labels
kubectl get endpointslice -n releaseops -l kubernetes.io/service-name=release-service -o yaml
```

Typical root causes:

- Service selector does not match Pod labels
- matching Pods are not Ready
- Service is in a different namespace
- wrong target port or named port

Important distinction:

```text
No endpoints       -> discovery/readiness/selector problem
Endpoints exist but fail -> port, application, policy, or network problem
```

## Scenario 9: Service DNS Does Not Resolve

Test from inside a disposable debug Pod only when cluster policy permits it:

```bash
kubectl run dns-debug -n releaseops --rm -it --restart=Never --image=busybox:1.36 -- nslookup release-service
```

Then check:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get service -n kube-system kube-dns
kubectl get networkpolicy -n releaseops
```

Common causes:

- wrong service name or namespace
- CoreDNS unavailable
- DNS egress blocked by NetworkPolicy
- node DNS configuration issue
- application using an external search domain incorrectly

The fully qualified in-cluster name is commonly:

```text
release-service.releaseops.svc.cluster.local
```

## Scenario 10: NetworkPolicy Blocks Traffic

First draw the intended flow:

```text
source Pod -> source egress -> destination ingress -> destination port
```

Inspect both namespaces and both workloads:

```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy -n releaseops
kubectl get pods -n releaseops --show-labels
kubectl get namespace --show-labels
```

Check:

- policy selects the intended Pod
- namespace labels match the selector
- destination port is correct
- DNS egress is allowed
- both directions permit the connection where needed
- the CNI actually enforces NetworkPolicy

Production gotcha:

Applying default deny before allow policies can create an outage. Roll out
policy with observed traffic, tests, staged namespaces, and a rollback path.

## Scenario 11: Ingress Returns 404, 502, Or 503

Interpret status carefully:

- `404` often means host/path did not match a routing rule
- `502` often means connection or protocol failure to backend
- `503` often means no healthy backend endpoints

```bash
kubectl get ingress -n releaseops -o wide
kubectl describe ingress <name> -n releaseops
kubectl get service,endpointslice -n releaseops
kubectl logs -n <controller-namespace> deployment/<ingress-controller>
```

Trace each hop:

```text
DNS -> load balancer -> Ingress controller -> rule -> Service -> EndpointSlice -> Pod
```

Do not assume the Ingress YAML itself runs a proxy. Confirm the controller and
IngressClass exist.

## Scenario 12: HPA Does Not Scale

```bash
kubectl get hpa -n releaseops
kubectl describe hpa release-service -n releaseops
kubectl top pods -n releaseops
kubectl get deployment release-service -n releaseops -o yaml
```

Check:

- metrics source is available
- target Pods have CPU requests
- current load exceeds target long enough
- HPA min/max permit movement
- scale-down stabilization is intentionally delaying reduction
- new replicas can actually schedule

If HPA creates replicas that stay Pending, HPA is working. The remaining problem
is cluster capacity or scheduling.

Production gotcha:

GitOps may continually reset `spec.replicas` if the Deployment manifest declares
it while HPA also owns it. Our chart omits replicas when autoscaling is enabled.

## Scenario 13: PDB Blocks Node Drain

```bash
kubectl get pdb -n releaseops
kubectl describe pdb -n releaseops
kubectl get deployment -n releaseops
```

Example:

```text
replicas = 1
PDB minAvailable = 1
```

No voluntary eviction is allowed. Options must be selected deliberately:

- add a healthy replica first
- relax the PDB through an approved change
- reschedule capacity
- use force only with explicit acceptance of downtime and risk

Never delete a PDB automatically merely because drain is inconvenient.

## Scenario 14: PVC Stays Pending

```bash
kubectl get pvc,pv -n observability
kubectl describe pvc <claim> -n observability
kubectl get storageclass
kubectl get events -n observability --sort-by=.metadata.creationTimestamp
```

Check:

- StorageClass exists
- provisioner/CSI driver is healthy
- requested access mode is supported
- topology and zone constraints can be satisfied
- requested size is allowed
- cloud quota and permissions permit provisioning

Production gotcha:

With `WaitForFirstConsumer`, Pending PVC can be expected until a Pod is scheduled.
Read events before treating every Pending claim as a fault.

## Scenario 15: RBAC Forbidden

An error normally includes identity, verb, resource, and namespace.

```text
User "system:serviceaccount:releaseops:worker" cannot list resource "pods"
in API group "" in the namespace "releaseops"
```

Test the exact permission:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:releaseops:worker -n releaseops
```

Then inspect:

```bash
kubectl get role,rolebinding -n releaseops -o yaml
kubectl get clusterrole,clusterrolebinding -o yaml
```

Fix only the required verb/resource/scope. Avoid broad wildcard rules and
cluster-wide bindings when namespace access is enough.

## Scenario 16: ConfigMap Changed But App Uses Old Value

Determine how configuration is consumed:

- environment variable
- mounted file
- application-side dynamic reload

```bash
kubectl get configmap release-service -n releaseops -o yaml
kubectl get deployment release-service -n releaseops -o yaml
kubectl rollout history deployment/release-service -n releaseops
```

Environment variables require new Pods. Our Helm chart includes a ConfigMap
checksum in the Pod template, so a rendered configuration change creates a new
Deployment revision.

Production gotcha:

Never print an entire Secret merely to compare configuration. Inspect metadata,
key names, version source, and controlled hashes without exposing values.

## Scenario 17: Rollout Is Stuck

```bash
kubectl rollout status deployment/release-service -n releaseops --timeout=2m
kubectl describe deployment release-service -n releaseops
kubectl get replicaset,pod -n releaseops
kubectl get events -n releaseops --sort-by=.metadata.creationTimestamp
```

Check:

- new Pods Pending
- image pull failure
- startup/readiness failure
- quota prevents surge Pod
- strict anti-affinity prevents placement
- old Pods cannot terminate
- PDB and rollout settings conflict operationally

Rollback decision:

Rollback when the new revision is proven bad and rollback is safe. Do not use
rollback to conceal a forward-only database migration incompatibility.

## Scenario 18: Pod Is Stuck Terminating

```bash
kubectl describe pod <pod-name> -n releaseops
kubectl get pod <pod-name> -n releaseops -o yaml
```

Possible causes:

- application ignores SIGTERM
- long `preStop` hook
- finalizer is waiting
- volume detach/unmount delay
- kubelet or node is unreachable

Force deletion removes the API object but does not guarantee the process stopped
on an unreachable node. Use it only after understanding duplicate-work and data
integrity risk.

## Scenario 19: Node NotReady And Pods Evicted

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl get pods -A --field-selector spec.nodeName=<node-name>
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

Check conditions:

- `MemoryPressure`
- `DiskPressure`
- `PIDPressure`
- `Ready`

Also inspect kubelet, runtime, CNI, node network, certificates, and cloud or
machine health through the platform's node-management tooling.

Kubernetes can replace Pods elsewhere only if capacity and controllers exist.
A single unmanaged Pod has no controller to recreate it.

## Scenario 20: A Manual Fix Keeps Disappearing

This is usually reconciliation, not mystery.

Possible owners:

- Deployment controller
- HPA
- admission webhook
- Helm release
- GitOps controller
- infrastructure controller

Check object metadata and managed fields:

```bash
kubectl get deployment release-service -n releaseops -o yaml --show-managed-fields
```

Fix the declared source of truth. A manual cluster edit may be useful during an
incident, but the durable fix belongs in Git or the owning controller's input.

## Real Interview Anecdote Structure

Do not tell a troubleshooting story as a command dump. Use:

```text
Situation -> impact -> evidence -> root cause -> fix -> verification -> prevention
```

Example based on the lab:

> A managed storage controller timed out during provisioning and its Pods were
> repeatedly restarting. I did not immediately recreate the cluster. I checked
> the controller Pods, previous logs, events, cloud permissions, and Terraform
> state. The controller lacked the workload identity needed to call the storage
> API. I added a dedicated least-privilege identity association, verified every
> controller container became Ready, and confirmed Terraform returned to a clean
> plan. The prevention was to model add-on identity as part of the add-on module
> and document the dependency.

That story demonstrates layered diagnosis, IAM awareness, state awareness,
least privilege, and verification without exaggerating production impact.

## Production Incident Checklist

Before changing anything, capture:

- incident start time and affected services
- last known good version
- recent deployment/configuration/policy changes
- Pod states and restart counts
- relevant events and previous logs
- Service endpoints
- dependency and node health
- current rollback path

After recovery, record:

- exact root cause
- customer or service impact
- why detection did or did not work
- why safety controls did or did not work
- code/runbook/alert/policy changes
- owner and due date for prevention work

The strongest DevOps answer is not "I know many kubectl commands." It is "I can
move from symptom to evidence, restore service safely, and reduce recurrence."
