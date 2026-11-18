# RBAC – My Part

### WHAT IS RBAC?
- Built-in Kubernetes security feature.
- Controls what each ServiceAccount can access and do.
- Uses Roles, ClusterRoles and bindings to assign permissions.
- Basically, gives applications only the permissions they need.

### HOW DOES IT HELP?
- If someone steals a ServiceAccount token, they get that account's permissions.
- RBAC limits what they can do with it.
- Example: If an account can only read Pods, attacker can't just delete Pods or read Secrets.
- Less permissions = less damage.

### LIMITATIONS
- Doesn't stop someone from stealing the token.
- Can't tell if it's the real application or an attacker using the stolen token.
- If an account has too many permissions, attacker gets those too.
- Some permissions can lead to privilege escalation.
- Doesn't detect suspicious activity by itself.

### HOW WE CAN TEST IT (PRACTICAL)
- Create two ServiceAccounts:
  - One with broad permissions.
  - One with restricted permissions.
- Check what each account can do.

Example:
- Read Pods - allowed.
- Delete Pods - denied for restricted account.
- Read Secrets - denied for restricted account.
- Create Deployments – denied for restricted account.

Compare both accounts and show how restricted permissions reduce the damage.

### EVALUATION
- Easy to set up because Kubernetes already has RBAC.
- Helps reduce the attack surface.
- Need to be careful when assigning permissions.
- Too many restrictions can affect applications.
- Needs regular permission reviews.

### FINAL THOUGHT
- RBAC doesn't prevent token theft.
- It limits what an attacker can do after stealing the token.
- Should be combined with monitoring and other security methods.
