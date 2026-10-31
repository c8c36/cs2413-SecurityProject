**WHAT IS CURRENTLY AVAILABLE**

solutions fall into layer because abuse shows up in different places depending on how the token was stolen or used

*WHAT WE TRY TO CATCH:*
theft - something reads token inside pod or attacker execs in to grab it
use: token is in places it shouldn’t be or does work that never does (enumeration, secret reads, RBAC changes)
Minting and persistence: attaker uses tokenReq to create tokens that never touch a filesystem

*THERE IS NO SINGLE TOOL that can cover all this issues so we have to combine runtime monitoring (theft) with auditlog analysis (use and minting)/*

**FALCO**

WHAT IS IT?
- Falcos's driver captures system calls on each node and passes them to userspace, where the rule engine evaluates them. 
- Falco takes the event stream, checks it agaisnt its rules and alerts when a rule is violated
- Falco can use audit logs and metadata as another event source - but it needs a separate setup (a plugin and an audit webhook)
- Sycall side sees what happens inside the containers

HOW TO APPLY IT IN TOKEN ABUSE
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

**ELASTIC RULES**
WHAT IS ELASTIC: 
    -  a company whose security product analyzes log data and includes prebuilt detection rules. For Kubernetes, its rules analyze audit logs.
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
RESOURCES ETC

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