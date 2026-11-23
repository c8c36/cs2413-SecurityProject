# Scenario

<!--toc:start-->

- [Scenario](#scenario)
  - [Setup Scenario](#setup-scenario)
    - [kubectl](#kubectl)
    - [Headlamp](#headlamp)
  - [Scenario Problem Demonstartion](#scenario-problem-demonstartion)
    - [Python Script Using Requests](#python-script-using-requests)
  - [Proposed Solution](#proposed-solution)
    - [Create Strict Environment](#create-strict-environment)
    - [Falco Monitoring And Honeytokens](#falco-monitoring-and-honeytokens)

<!--toc:end-->

The container has been compromised, and the attacker has access level comparable
to the process.

By default the service account token is stored under
`/var/run/secretes/kubernetes.io/serviceaccount` as `token` file.

## Setup Scenario

Apply the `manifests/baseline/baseline-state.yaml` file to the cluster. There
are two ways provided to do it:

1. [kubectl](#kubectl)
2. [Headlamp web UI](#headlamp) at `http://localhost:30000`

### kubectl

1. Get access to the console either from VirtualBox GUI window using `lab`-`lab`
   credentials **or** over ssh using the following command:

   ```bash
   ssh -o PasswordAuthentication=yes -o PubkeyAuthentication=no -l lab localhost -p 2222
   # Answer yes if asked by ssh about the connection
   ```
2. Create/copy `manifests/baseline/baseline-state.yaml` and apply the manifests:

   ```bash
   sudo kubectl apply -f baseline-state.yaml
   ```

### Headlamp

1. Make sure the virtual machine is online; open your browser and navigate to
   headlamp web GUI at `http://localhost:30000`. Be patient, depending on the
   hardware it may take a couple of minutes to start.

2. Press **CREATE** button at the bottom left, copy-paste the content from
   `baseline-state.yaml`, and continue with **SAVE-APPLY**

## Scenario Problem Demonstartion

The scenario that the `baseline-state.yaml` creates presents a difficult
challenge: there is no meaningful way to distinguish legitimate jobs it creates
from illegitimate.

```bash
export TOKEN= # put service account token value here
```

```bash
curl -k -X POST -H "Authorization: Bearer $($TOKEN)" \
                -H "Content-Type: application/yaml" \
                "https://kubernetes.default/apis/batch/v1/namespaces/default/jobs" \
                --data '
apiVersion: batch/v1
kind: Job
metadata:
  name: oops-hijacked-credentials
  namespace: default
spec:
  template:
    metadata:
      name: oops-hijacked-credentials
      namespace: default
    spec:
      restartPolicy: Never
      containers:
        - name: oops
          image: python:3.15-bookworm
          command: ["bin/bash", "-c", "--"]
          args: ["while true; do sleep 60; done;"]
      serviceAccountName: job-controller
      automountServiceAccountToken: true
'
```

### Python Script Using Requests

The easiest way to demonstrate this is to: navigate to the headlamp web GUI
(`http://localhost:30000`), access the `target-pod` under Pods/Workloads, and
navigate to the pods web-console under the terminal button labelled as
`Terminal/Exec`.

The following script can be then copy-pasted into the terminal window:

```bash
python -m pip install requests
cat <<EOF | python -
payload = '''apiVersion: batch/v1
kind: Job
metadata:
  name: oops-hijacked-credentials
  namespace: default
spec:
  template:
    metadata:
      name: oops-hijacked-credentials
      namespace: default
    spec:
      restartPolicy: Never
      containers:
        - name: oops
          image: python:3.15-bookworm
          command: ["bin/bash", "-c", "--"]
          args: ["while true; do sleep 60; done;"]
      serviceAccountName: job-controller
      automountServiceAccountToken: true
'''

with open("/var/run/secrets/kubernetes.io/serviceaccount/token") as f:
    token = f.read()

from requests import request
r = request("POST", \
"https://kubernetes.default/apis/batch/v1/namespaces/default/jobs", \
verify=False, \
data=bytes(payload, "utf-8"), \
headers={"Authorization": f"Bearer {token}", \
"Content-Type": "application/yaml"})

print(r.ok)
EOF
```

## Proposed Solution

The solution demonstrates an example of defence-in-depth approach combining
RBAC, validation policies, monitoring, and decoy to protect the cluster from
compromised container. The exact setup would address well-defined attack vectors
that can only be deduced by looking at the exact application and business
requirements.

### Create Strict Environment

To create a more strict environment that supplements RBAC with strict validating
admission policy apply the following files to the cluster:

1. `manifests/policy-readonly-rootfs.yaml`: invalidate Jobs that are not root
   filesystem readonly.
2. `manifests/policy-remove-token-access.yaml`: invalidation any Jobs asking for
   a service account token access requests.
3. `manifests/policy-restrict-volumes.yaml`: invalidate any Jobs requesting
   volume access and only allow ephemeral emptyDir volume requests.
4. `manifests/policy-strict-security-context.yaml`: invalidate any Jobs
   requesting any kind of privilege including access to the host.

Refer to `manifests/secure-job.yaml` for example of a job that would pass the
validation policies, and `shell/good_job.sh` similar Job scripted with Python
requests.

### Falco Monitoring And Honeytokens

To create Falco service on the cluster with custom honeytoken rule apply
`manifests/falco-honeytokens.yaml` file to the cluster.

This will create a Falco service that will watch for any read on
`/var/run/secrets/kubernetes.io/serviceaccount/token` under `unsafe-jobs-prod`
namespace. Any read of this file is to be assumed a sign of compromise because
the application running in this namespace is assumed to be aware that the real
token is mounted under different folder; hence, any other read is a sign of
intrusion.
