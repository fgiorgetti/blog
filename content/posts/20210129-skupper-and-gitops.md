---
title: "Skupper and Gitops"
date: 2021-01-29T18:27:23-03:00
draft: true
---

Skupper enables service communication, transparently,
across multiple hybrid Kubernetes clusters.

For more information about Skupper, as well as documentation and
great examples, please visit [https://skupper.io/](https://skupper.io/).

This article will demonstrate how to setup and maintain a Virtual Application Network (VAN)
using Skupper.

The standard documented approach for setting up a Skupper network, is
through the use of its Command Line Interface (CLI) tool named `skupper`.

Following the documentation and some examples, you will connect your network
through a set of imperative commands that are used to initialize and connect
your network.

This approach works just fine. But imagine if you have a set of services
to be exposed and you have multiple sites to maintain.

Your services may need to change from time to time and/or you might need to
recover one of your sites if something goes wrong. To keep everything in shape,
you will need to execute multiple commands or write a set of scripts so your 
environment is always at the expected state, and this is not a trivial thing
to achieve.

The goal here is to demonstrate how you can setup a GitOps operator in your
cluster, so that all your Cloud Application, as well as your Hybrid network
can always be up to date with your desired state.
