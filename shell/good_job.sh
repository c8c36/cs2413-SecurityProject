python -m pip install requests
cat <<EOF | python -
payload = '''
apiVersion: batch/v1
kind: Job
metadata:
  name: calculation
  namespace: unsafe-jobs-prod
spec:
  template:
    spec:
      restartPolicy: Never

      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault

      containers:
        - name: calculation
          image: cgr.dev/chainguard/busybox:latest
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - -c
            - |
              echo "Secure Job started"
              echo "Running as:"
              id
              echo "Attempting to write to root filesystem:"
              touch /root/test 2>&1 || true
              echo "Writing to the permitted temporary directory:"
              echo "Job completed successfully" > /tmp/job-result
              cat /tmp/job-result

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]

          volumeMounts:
            - name: scratch
              mountPath: /tmp

      volumes:
        - name: scratch
          emptyDir:
            sizeLimit: 1Gi

'''

with open("/var/run/application-id/token") as f:
    token = f.read()

from requests import request
r = request("POST", \
"https://kubernetes.default/apis/batch/v1/namespaces/unsafe-jobs-prod/jobs", \
verify=False, \
data=bytes(payload, "utf-8"), \
headers={"Authorization": f"Bearer {token}", \
"Content-Type": "application/yaml"})

print(r.ok)
EOF
