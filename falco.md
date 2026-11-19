# WHAT IS CURRENTLY AVAILABLE

solutions fall into layer because abuse shows up in different places depending on how the token was stolen or used

### WHAT WE TRY TO CATCH:
theft - something reads token inside pod or attacker execs in to grab it
use: token is in places it shouldn’t be or does work that never does (enumeration, secret reads, RBAC changes)
Minting and persistence: attaker uses tokenReq to create tokens that never touch a filesystem

*THERE IS NO SINGLE TOOL that can cover all this issues so we have to combine runtime monitoring (theft) with auditlog analysis (use and minting)/*

# FALCO

**WHAT IS IT?**
- Falcos's driver captures system calls on each node and passes them to userspace, where the rule engine evaluates them. 
- Falco takes the event stream, checks it agaisnt its rules and alerts when a rule is violated
- Falco can use audit logs and metadata as another event source - but it needs a separate setup (a plugin and an audit webhook)
- Sycall side sees what happens inside the containers

### HOW TO APPLY IT IN TOKEN ABUSE
There exists two detection ideas

1. SOMEONE READ THE TOKEN FILE
- Token sists in /var/run/secrets/kubernetes.io/serviceaccount/token
- We need to create a new specfic custom rule, because Falco’s default sensitive-file rules (version 0.36.1) cover files like /etc/shadow and sudoers, but not the service account token path, so detecting token reads requires a custom rule. Newer versions may differ.
- I did not find a community-vetted baseline. Each team writes its own allowlist, this is why results can vary and noise problem is so hard to generalized

- EXAMPLE OF A RULE (for visualization, not tested):

```
- list: sa_token_trusted_images
  items: []   # fill per cluster: operators, ingress controllers, monitoring agents

- rule: Service Account Token Read In Container
  desc: A process opened a Kubernetes service account token from an untrusted image
  condition: >
    open_read and container
    and fd.name contains "kubernetes.io/serviceaccount"
    and fd.name contains "token"
    and not container.image.repository in (sa_token_trusted_images)
  output: >
    SA token read (file=%fd.name process=%proc.name cmdline=%proc.cmdline
    image=%container.image.repository ns=%k8s.ns.name pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, credential_access, k8s]
```


2. A CONTAINER IS TALKING TO THE API SERVER UNEXPECTEDLY

- Falco's default rule: "Contact K8S API Server From Container"
    - flags connect calls from containers to the Kubernetes API server, excluding containers in k8s_containers macro and any matched by the user-defined: user_known_contact_k8s_api_server_activities macro.
    - Doesn't reference tokens. Its relevant because to token abuse because anyone using a stolen token must reach the API server. 
    - it observes the connetin, not the API call and also it legimite softare connects too
    - For that reason we need to do per-environment tuning
    - The rule's decription recommends to supplementing it with Kubernetes audit logs via k8saudit plugin.

    - THE RULE:

Condition:

evt.type=connect and (fd.typechar=4 or fd.typechar=6) and container and k8s_api_server and not k8s_containers and not user_known_contact_k8s_api_server_activities


- LIMITS: The token-read rule cannot see tokens created through TokenRequest, because no file is read. The API-contact rule only sees connections from containers on nodes where Falco runs, so it misses a stolen token used from outside the cluster, and it never observes the minting event itself. Audit-log detection (TokenRequest events, requests from unexpected sources) is needed to cover these cases.
---

# ELASTIC RULES
WHAT IS ELASTIC: 
    - a company whose security product analyzes log data and includes prebuilt detection rules. For Kubernetes, its rules analyze audit logs.
    - WE WILL USE: its prebuilt SIEM rules for Kubernetes audit logs

AUDIT LOGS
- WHAT IS IT?
    - KS's auditing records a chronological sequence of actions in the cluster
    - An audit poliocy will decide what gets logged
    - LEVELS: None, Metadata, RequestResponse
    - Audit logs need to be enabled 
    - The log level limits detection. Some details, such as a minted token’s duration, aren’t visible when logging only captures metadata.

HOW TO APPLY IT

1. A TOKEN IS MINTED (TOKENREQUEST)
- Detect a create on serviceaccounts/token subsource by someone who is not a system component
- Elastic's rule calls this a token that leaves no filesystem footprint and appear only in audit logs. Their rule filters for create requests on the token subresource, excluding the kube-controller-manager user and the system:nodes group.
- ELASTIC RULE:

```
data_stream.dataset:"kubernetes.audit_logs" and
kubernetes.audit.verb:"create" and
kubernetes.audit.objectRef.resource:"serviceaccounts" and
kubernetes.audit.objectRef.subresource:"token" and
user.name:(* and not
 (system\:kube-controller-manager or
  system\:kube-scheduler or
  system\:node\:* or
  system\:serviceaccount\:kube-system\:* or
  eks\:* or
  aksService or
  aks-service or
  masterclient or
  nodeclient or
  system\:serviceaccount\:gke-managed-system\:* or
  system\:serviceaccount\:gke-connect\:* or
  system\:serviceaccount\:anthos-identity-service\:* or
  system\:gke-controller-manager or
  system\:serviceaccount\:tigera-operator\:* or
  system\:serviceaccount\:calico-system\:*))
```

NOTE: Noise: Elastic’s rule excludes a long list of legitimate identities, including the scheduler, controller manager, nodes, kube-system service accounts, managed-cloud identities, and the Calico and Tigera operators. Each cluster will have its own additions, just like the Falco allowlists

2. A SERVICE ACCOUNT IS DENIED (enumeration)
- Elastic rule: “Kubernetes Denied Service Account Request”
-  flags service-account requests the authorizer forbade, on the basis that service accounts follow predictable patterns and should never send an unauthorized request. 
- RULE:

event.dataset: "kubernetes.audit_logs"
  and kubernetes.audit.user.username: system\:serviceaccount\:*
  and kubernetes.audit.annotations.authorization_k8s_io/decision: "forbid"

NOTE: scripts, test accounts, third-party integrations and misconfigured RBAC can all trigger false positives

----
# APPLICATION OF FALCO

## HOW TO DONWLOAD FALCO INTO KUBERNETES WITH HELM

- First we need to add the Falco chart repository to Helm:
```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
```
- Then we need to install Falco:
```
helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco
```
- To be sure, its appropiate to check that Falco pods are running:
```
kubectl get pods -n falco
```
- Before we can begin working with the pods we need to make sure and wait until they are ready:
```
kubectl wait pods --for=condition=Ready --all -n falco
```
NOTE: the pod is ready when it shows 2/2 Running

## HOW TO ADD A NEW CUSTOM RULE
- Its important to notice and remember that Falco's default rules do not cover service account token reads, for that we are required to add our own custom ones.
- Since we installe Falco with Helm, the custom rules we created are passed in through a value file.

#### STEP 1
  - Lets start creating a file called custom-rules.yaml:
```
nano custom-rules.yaml
```
#### STEP 2
  - Inside of the file we just created, we would write in our custom rule.
  - REMINDERS: 
        - The indentation matters becauase its a YAML file.
        - The top-level key must be customRules. A mistake I made was to write custom-rules, Helm will accept the file but the file will be silently ignored 
```
customRules:
  rules-token.yaml: |-
    - list: sa_token_trusted_images
      items: [trusted-placeholders]

    - rule: Service Account Token Read In Container
      desc: A process opened a Kubernetes service account token from an untrusted image
      condition: >
        open_read and container
        and fd.name contains "kubernetes.io/serviceaccount"
        and fd.name contains "token"
        and not k8s.ns.name in (kube-system, apps)
        and not container.image.repository in (sa_token_trusted_images)
      output: >
        SA token read (file=%fd.name process=%proc.name cmdline=%proc.cmdline
        image=%container.image.repository ns=%k8s.ns.name pod=%k8s.pod.name)
      priority: WARNING
      tags: [container, credential_access, k8s]
```
*WHAT DOES THE RULE DOES:*
- The rule will fire when a process inside a container opens the service account token file for reading (open_read and container, additionally the two fd.name conditions)
- Also, we included allowlists to avoid false positives:
      - The namespaces kube-system and apps are treated as normal

#### STEP 3
  - Now, we ned to apply the rule file to the existing Falco installation:
```
helm upgrade falco falcosecurity/falco -n falco --set tty=true -f custom-rules.yaml
```
#### STEP 4
- Falco only reads its rules when it starts. We gonna restart it and wait until the pods are 2/2 Running:
```
kubectl rollout restart daemonset falco -n falco
kubectl get pods -n falco -w
```
NOTE: if you want to stop press CTRL + C

#### STEP 5
- To finalize, we need to check that the rule is loaded. The logs should show rules-token.yaml under "Loading rules from" with schema validation: ok (with no errors, of course):
```
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=40 | grep -i -E "rules|error"
```
if all ok, rule has been loaded!!

----
# SCENARIOS: LEGIMATE BEHAVIOUR VS ILLEGIMATE 

- We have created a custom rule! but now we need to make sure that rule works. 
- We will run the same action in two places:
    - a pod in the allowlisted namescape (normal behaviour)
    - a pod in the default namescape (attack)

## NORMAL BEHAVIOUR
- Start by creating the apps namescape and a pod inside of it
```
kubectl create namespace apps
kubectl run legit -n apps --image=busybox --restart=Never -- sleep 86400
kubectl get pod legit -n apps
```
- Once the pod is runnin, read the token:
```
kubectl exec -n apps legit -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```
## ATTACK BEHAVIOUR
- Here we going to simulate an attacker who got into a pod and steals its token
```
kubectl run test --image=busybox --restart=Never -- sleep 86400
kubectl exec test -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```
#### COMPARING RESULTS
- We are going to look into Falco's logs for both pods
```
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=200 | grep -E "pod=(test|legit)"
```
- RESULTS:
    - test (namescape default): Falco show the warning (Warning SA token read) alert with the file path, the process (cat), the image (busybox), the namescape and the pod name
    - legit (namescape apps): no alert shown

----
## CONCLUSION
- The rule we created detects a token being read inside a container and gives appropiate information to investigate (pod, namespace, image, process and command line)
- Because Falco rules are plain YAML conditions, they are fairly easy to write, tune and script
---
## LIMITATIONS
- The allowlist is a blind spot, an attacker who compromises inside apps would not be flagged
- A token created in TokenRequest API never touches a file, so this specific rule cannot detect it. This is why we need audit-log detection 
- A token used from outside the cluster is not detected with this rulw
- This rule is only for detection, it does not stop the attacker

## ASSUMPTIONS 
- This demo is simplified for the sake of time and space (presentation and report), a full set up needs a lot of more rules. A single rule can't catch every way a token can be abused

1. We dont show how the attacker got in. The demo starts when they are already inside and kubectl exec plays as the attacker running commands inside the pod

2. RBAC is already assumed, as it decides what each service account is allowed to do. We assume that attacker (in simple terms) has a normal, low privilege service account (kubernetes default), so no admin access. Attacker cannot create pods or namespaces in trusted apps namespace

3. Attacker is stuck inside the untrusted pod because of RBAC, so when they steal the token from an untrusted pod, the rule fires

4. Admin created legit pod and apps namespace to showcase normal activity because those are things attacker cannot do
---- 
# SCREENSHOTS
<img width="952" height="637" alt="Screenshot 2026-11-19 174548" src="https://github.com/user-attachments/assets/870cb4fb-4919-4f47-bd81-d9f96f34dfa3" />

----

<img width="1022" height="700" alt="Screenshot 2026-11-19 180249" src="https://github.com/user-attachments/assets/6b7a99e6-29da-4ba8-9e02-e44e4c58cf2a" />
----
<img width="1290" height="375" alt="Screenshot 2026-11-19 180833" src="https://github.com/user-attachments/assets/95c18463-6f93-49f8-bc7e-42e1188734c3" />
----
<img width="1287" height="442" alt="Screenshot 2026-11-19 181250" src="https://github.com/user-attachments/assets/c31d9e3d-a330-4c8b-9269-fafc65bf70a6" />
----
<img width="1295" height="92" alt="Screenshot 2026-11-19 181526" src="https://github.com/user-attachments/assets/07c7cfc1-95df-4816-b969-bbb586bd4a9b" />


----
# RESOURCES ETC

Runtime Security with Falco on Kubernetes: Rules, Tuning, and Response Automation:
https://www.systemshardening.com/articles/kubernetes/falco-runtime-security/ 

How to Use Falco for Kubernetes Runtime Security :
https://oneuptime.com/blog/post/2026-02-20-kubernetes-runtime-security-falco/view 

Falco:
https://falco.org/docs/reference/rules/default-rules/ 

Comparative Analysis of eBPF-Based Runtime Security Monitoring 
Tools in Monitoring and Threat Detection on Kubernetes : 
https://www.scitepress.org/publishedPapers/2025/142727/pdf/index.html 

elastic service acc token created via tokenreq api:
https://www.elastic.co/guide/en/security/current/kubernetes-service-account-token-created-via-tokenrequest-api.html 

elastic rule denied service acc req:
https://www.elastic.co/guide/en/security/8.14/kubernetes-denied-service-account-request.html
