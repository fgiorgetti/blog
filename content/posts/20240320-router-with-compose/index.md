---
title: "Running skupper-router containers with compose"
date: 2024-03-20T09:14:27-03:00
draft: true
toc: false
tags:
  - skupper
  - skupper-router
  - docker
  - docker-compose
  - podman
  - podman-compose
---
A compose file can also be an interesting way to run a static bundle for skupper-routers.
Here I am using a two routers network, named west and east.

The west router has an inter-router link (secured with TLS) defined to connect with the
east one (using skupper-router-east hostname).

All the configuration files, sample certificates and compose files can be downloaded by clicking
the following link: [Example files (tarball)](example.tar.gz).

Once you extract the tarball, you will fine a new directory named example which contains
the `compose.yaml` file, as well as all the configuration needed by the two routers under
`./example/west` and `./example/east`.

This `compose.yaml` file, works with both docker and podman.

To deploy this multi-container scenario, run:

| Docker | Podman |
| ------ | ------ |
| docker compose up -d | podman-compose up -d |

To teardown this multi-container scenario, run:

| Docker | Podman |
| ------ | ------ |
| docker compose down | podman-compose down |

_**Note:**_ To install `podman-compose`, follow the [official instructions](https://github.com/containers/podman-compose?tab=readme-ov-file#installation).
