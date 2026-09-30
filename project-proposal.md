# Kubernetes Service Token Theft Countermeasures

Related to: Intrusion Detection, Role-Based Access Control, Password Security
and Authentication.

## Problem Statement

Q: What security problem is being addressed?

This project addresses an attack vector: Kubernetes service account token
compromise. We aim to find and evaluate ways to efficiently detect, contain, or
prevent cluster-wide impact from service account token compromise.

## System

Q: What type of system, application, network, database, or data will be
considered?

The project will use a pre-configured Kubernetes cluster. The cluster will, for
demonstration sake, run a compromisable workload containing service account
token.

For context, Kubernetes cluster is a container orchestration tool capable of
simultaneously managing multiple containerized workflows (usually applications,
but it is technically more than that). The Kubernetes cluster itself consists of
multiple control services, and for this project `kube api server` is the target.
The way humans, and by extension applications, interact with a cluster is
through `kube api server` with https requests using identities presented through
service account tokens. It is fairly common to give a service account token to
an application, so it can perform jobs directly on the cluster.

## Security Objectives

Q: What needs to be protected (e.g., confidentiality, integrity, availability,
authentication, or access control)?

Limitation, detection, or mitigation of service account token compromise on
Kubernetes cluster requires looking at this issue while targetting different
security objectives. We want to look into access control (RBAC),
confidentiality, or authentication security objectives to thoroughly asssess
potential approaches to securing a service account token.

## Threats

What are the main threats or attacks relevant to the system?

For this project, the attacker has already compromised the workload running with
a service account token. Surprisingly, this is fairly realistic attack vector
for a Kubernetes cluster hosting many applications.

Compromise of a service account token allows the attacker to contact
`kube api server` to move laterally through the cluster. Since it is not rare
that a Kubernetes cluster may control multiple nodes (machines), the exact
attack impact may span from service unavailability to full compromise of entire
infrastructure.

## Proposed Security Mechanism

What security technique, tool, or mechanism will be implemented or configured?

This project will examine the following mechanisms for service account token
security and potentially propose a combination of them:

1. Role-Based Access Control configuration for service account tokens and their
   limitations.
2. Honeypot-canary tokens: alerting the system if honeypot token was used.
3. Short-lived tokens: temporary tokens with time-gating.
4. Currently available solution for monitoring token usage (and misusage).

## Planned experiments

Briefly describe how the effectiveness of the solution will be evaluated

Each security mechanism to limit, detect, or mitigate token abuse will be
evaluated against criteria: easiness of implementation, relative attack surface
reduction (or difficulty of exploitation), and limitation it emposes upon
environment. The last criteria is a reasonable guess that examines restrictions
it emposes on potential application and potential increase in development costs
for the application itself running with this security solution.

## Expected outcomes

What do you expect to demonstrate or learn from the project?

Major learning outcomes: learning how Kubernetes cluster works, and protecting
application credentials.

Minor learning outcomes: learning the trade-offs between different combination
of solutions, and learning more about containerized workflow including their's
security.

## Group Members and Responsibilities

Briefly indicate each member's expected contribution.

**SUBJECT TO CHANGE**

- Bohdan Savchuk: general organization, direction, assistance, Kubernetes
  cluster physical setup.
- Maan Patel: review for role-based access control with Kubernetes service
  account tokens with focus on limitations.
- Nathan Britto: review for usage of honeypot-canary tokens with focus on their
  viability.
- Tasfi Samad Choudhury: review for usage of short-lived service account tokens
  with focus on their viability.
- Valeria Gabriela Palomino Paredes: review currently available solutions for
  monitoring account service token abuse for Kubernetes.

Everybody is expected to do a bit of coding; everybody can do extra if they wish
so. The list may change in case the approach turns out completely impractical,
or in any other unforeseen cases, and the instructor will be notified of the
change.
