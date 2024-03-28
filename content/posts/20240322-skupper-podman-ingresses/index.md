---
title: "Skupper service ingress through containers"
date: 2024-03-22T16:19:33-03:00
draft: false
toc: true
images:
tags:
  - skupper
  - skupper-router
  - podman
  - docker
  - compose
  - netfilter
  - iptables
  - edge
  - edge-router
  - haproxy
  - envoyproxy
  - iperf3
---

## Introduction

In order to evaluate some strategies for dealing with ingresses using a stable
name resolution within a container network (Podman or Docker), I have used the
following scenario as the foundation for this study:

![](images/scenario.png)

In the following sections, I will describe each component in more detail.

Artifacts for each strategy are also available and they can be easily executed
using _podman-compose_ or _docker compose_.

### Service Proxies

The service proxies are the main objects to be explored here.

Each service proxy is connected to a container network, and so they have a stable
name and an individual IP address within that network. With that, each proxy container
could bind port 8080 (as an example), because they'd have different IP addresses.

And this is the reason why we do not have a single proxy container with multiple
network aliases. Having multiple network aliases would solve the stable name issue,
but wouldn't allow two distinct names to bind the same port with different targets.

That being said, each proxy container will be responsible for redirecting incoming traffic
reaching its port(s) to the _skupper-router_ (explained later).

In this study we will evaluate different approaches that can be used to redirect
incoming traffic reaching the service proxies to the _skupper-router_.

Basically all the scenarios will use different approaches to redirect traffic to the listeners
exposed by the _skupper_router_, except for the _Edge-Router_ scenario, in which the service proxies
are edge-routers connected to the _skupper-router_ and they expose a _TCP Listener_ themselves.
These _TCP Listeners_ take the incoming traffic through the _skupper-router_ via its
_Edge Link_ with _skupper-router_, so the _TCP Listeners_ exposed by the _skupper-router_
are not used.

### Skupper Router

The _skupper-router_ component is connect to the host network, exposing TCP listeners
on ports _8080_ and _5201_, which have related TCP connectors reaching the _workloads_,
that are also running as containers, exposing their ports to the host network.

It is important to say that this is not an appropriate scenario for Skupper itself, as 
Skupper's purpose is to interconnect services distributed through the hybrid cloud, but
we are using it here to prove that we can get traffic from a service proxy redirected to
the _skupper-router_ and forwarded by the router to the respective _workloads_.

In the _Edge-Router_ scenario, the _skupper-router_ also exposes an _**Edge**_ listener
through port 45671. This listener is used by the _service proxies_ only in this scenario.

### Workloads

In this topology we have two workloads.

* _my-service_ - nginx server
* _my-tcp-service_ - iperf3 server

These workloads also run as containers and their ports exposed through the host machine and
mapping incoming traffic to the appropriate port used by the workload itself, here is the mapping:

* _my-service_ - Host port 8888 to container port 8080
* _my-tcp-service_ - Host port 4201 to container port 5201

The _skupper-router_ container has two TCP Connectors, one for each port, and the connectors
use the following configuration:

| Target host          | Target port | Routing key (address) |
| -------------------- | ----------- | --------------------- |
| host.docker.internal | 8888        | my-service:8080       |
| host.docker.internal | 4201        | my-tcp-service:5201   |

## Service proxy scenarios

1. Netfilter / iptables
2. Edge-router
3. HA proxy
4. Envoy proxy

### 1. Netfilter

Using Netfilter (iptables), we can simply add rules to redirect incoming packets reaching the
proxy containers (i.e: _my-service:8080_ and _my-tcp-service:5201_), to the respective
host ports that are bound by the _skupper-router_.

This is a simple solution as it just relies on an ubi9 image with iptables installed. It also seems
to be the fastest choice with minimal resource utilization, compared to the other approaches.

### 2. Edge-router

An edge-router can also be used, as we just need to expose a tcpListener on each container
with the respective routing key (address) that will reach the target workloads.

This approach has an extra benefit (to be evaluated) as you don't need to expose the workloads to the
container's host network (no TCP listener needed on the _skupper-router_), because it does not need a target
IP and Port.

Each service proxy runs as an edge-router and has an edge link to the _skupper-router_, which
targets host: host.docker.internal and port 45671.

### 3. HAProxy

The HAProxy can be configured as a reverse proxy, forwarding packets to the router
ingress IP and Port. HAProxy is also used by Openshift to provide Route ingress.

### 4. Envoy Proxy

Envoy proxy can be configured similarly to HAProxy. It is a safe, popular and reliable
alternative to be evaluated as well.

## Artifacts for evaluation

You can download and evaluate each of the approaches through the following links.
These samples can be run using `docker compose` or `podman-compose`.

[1. Netfilter](resources/netfilter.tar.gz)

[2. Edge-Router](resources/edgerouter.tar.gz)

[3. HAProxy](resources/haproxy.tar.gz)

[4. Envoy](resources/envoy.tar.gz)

## Validating each scenario

| Container engine | Deploy               | Teardown            | Environemnt      |
| ---------------- | -------------------- | ------------------- | ---------------- |
| Podman           | podman-compose up -d | podman-compose down | CONTAINER=podman |
| Docker           | docker compose up -d | docker compose down | CONTAINER=docker |

For each scenario, you can validate that you're able to access the target services through
Host's port 8080 (HTTP) and 5201 (TCP) as well as through the container's bridge network (_sample_sample1_),
through _my-service:8080_ and _my-tcp-service:5201_.

### HTTP

1. Access through the host:

`CLIENT -> ROUTER -> WORKLOAD`

```bash
curl http://0.0.0.0:8080
```

2. Access through the container's bridge network


`CLIENT -> PROXY -> ROUTER -> WORKLOAD`

_Note:_ The proxy can be one of: netfilter, edge-router, haproxy or envoy.

First adjust the value of the CONTAINER variable to the container engine being used (podman or docker).

```bash
CONTAINER=podman
${CONTAINER} run --rm --network sample_sample1 curlimages/curl http://my-service:8080
```

If you want to run a basic HTTP performance test (runs for 10s with 1 client and 10 connections),
you could also use:

```bash
CONTAINER=podman
${CONTAINER} run --rm --network sample_sample1 quay.io/skupper/wrk wrk -d 10s -c 10 -t 1 --latency http://my-service:8080
```

### TCP

1. Access through the host:

`CLIENT -> ROUTER -> WORKLOAD`

```bash
iperf3 -c 0.0.0.0
```

2. Access through the container's bridge network (with name resolution):

`CLIENT -> PROXY -> ROUTER -> WORKLOAD`

_Note:_ The proxy can be one of: netfilter, edge-router, haproxy or envoy.

First adjust the value of the CONTAINER variable to the container engine being used (podman or docker).

```bash
CONTAINER=podman
${CONTAINER} run --rm --network sample_sample1 quay.io/skupper/iperf3 -c my-tcp-service
```

## Conclusion

If requiring a host's IP/Port to be exposed is not a problem, the Netfilter/iptables approach
seems like the best fit as it requires few resources and seems to have best throughput.

But in case exposing workloads only into the container's network, without exposing them through the
host's IP and Port, is a mandatory thing, then Edge-router is the only choice that can be used.

As an upcoming activity, it would be really interesting to do a performance analysis, comparing all the
approaches mentioned here using both TCP (iperf3) and HTTP traffic.
