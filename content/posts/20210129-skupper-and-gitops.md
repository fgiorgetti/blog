---
title: "Maintaining your Skupper Virtual Application Network with Gitops"
date: 2021-01-29T18:27:23-03:00
draft: false
categories: [tutorial]
tags: [skupper, gitops, argocd]
---

## Hybrid Cloud using Skupper

Skupper enables service communication, transparently,
across multiple Kubernetes clusters.

For more information about Skupper, as well as documentation and
great examples, please visit [https://skupper.io/](https://skupper.io/).

This article demonstrates how to setup and maintain a
Virtual Application Network (VAN) using Skupper.

The standard documented approach for setting up a Skupper network, is
through the use of its Command Line Interface (CLI) tool named `skupper`.

Following its documentation and some examples, you will connect your
cloud applications through a set of imperative commands that will help you
setting everything up.

This approach works just fine. But imagine if you have a set of services
to be exposed and you have multiple sites to maintain.

Your exposed services may need to change from time to time and/or you might
need to recover one of your sites if something goes wrong. To keep everything
in shape, you will need to execute multiple commands or write a set of scripts
so your environment is always at the expected state, and this is not a trivial
thing to achieve.

Skupper provides a [Getting started](https://skupper.io/start/index.html) which shows how to connect two clusters using
the CLI. They also document connecting two clusters in Configuring Skupper sites using YAML.

In order to keep this tutorial simple, we will connect two namespaces in the same cluster while showing you how to use Argo CD.

## GitOps using Argo CD

The goal here is to demonstrate how you can setup a GitOps operator in your
cluster, so that all your distribute application, as well as your Virtual Application Network
can always be up to date with your desired state, or a single source of truth.

Argo CD helps you maintaining the state of your Kubernetes resources in sync
with a Git Repository (your source of truth).

Therefore all you need to do is keep your resources updated in your repository,
adjusting them as needed, and Argo CD will guarantee your cluster has always
the latest version you have defined.

In this tutorial, I am using a personal git repository. If you want to make changes to the resources used in this
example to observe Argo CD syncing it with your cluster, feel free to fork the [sample repository](https://github.com/fgiorgetti/skupper-example-hello-world.git) (branch: **gitops**) and update
the GIT url used in the upcoming sections.

## Setting up a local cluster

If you don't yet have a running cluster, you can follow the steps below to
download and run a local Minikube cluster in your machine.

[Minikube installation instructions](https://minikube.sigs.k8s.io/docs/start/).

## Installing your GitOps Operator

The instructions below have been copied from the [Argo CD Getting Started Guide](https://argoproj.github.io/argo-cd/getting_started/).

1. Create a namespace for the Argo CD operator

```
kubectl create namespace argocd
```

2. Install Argo CD from Installation YAML

```
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

3. Install the `argocd` CLI

Download the latest version of Argo CD CLI. Visit [https://github.com/argoproj/argo-cd/releases/latest](https://github.com/argoproj/argo-cd/releases/latest)
and download the binary for your operating system.

4. Expose your Argo CD Server locally

There are multiple ways you can use to get access to your Argo CD GUI, but
in order to keep this guide simple, we are going to create a port-forward
directly to the argocd-server service.

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Now you can access your API by using: `localhost:8080`.

You will see a page like:
![](/images/20210129-argocd-login.png)

5. Logging in using your CLI

    5.1. First we need to retrieve the generated password. To do so, run:

    ```
    $ kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2
    ```

    The returned output is the initial password. Please save it temporarily.



    5.2. Login using argocd


    ```
    $ argocd login localhost:8080
    WARNING: server certificate had error: x509: certificate signed by unknown authority. Proceed insecurely (y/n)? y
    Username: admin
    Password:
    'admin' logged in successfully
    Context 'localhost:8080' updated
    ```

    5.3. Update admin's password

    ```
    $ argocd account update-password
    *** Enter current password:
    *** Enter new password:
    *** Confirm new password:
    Password updated
    Context 'localhost:8080' updated
    ```


6. Creating an application from a Git Repository

The application we are going to deploy, in order to demonstrate how GitOps works
as well as how Skupper helps you, is a tiny HTTP application that runs across
two Kubernetes clusters (or in this demonstration, against two Kubernetes namespaces).

This [Hello World HTTP application](https://github.com/skupperproject/skupper-example-hello-world) is part
of the [Skupper's Examples WebSite](https://skupper.io/examples/).

It is composed by a Backend and a Frontend service. We are going to deploy each component to a different
namespace in our Kubernetes cluster.

![](https://github.com/skupperproject/skupper-example-hello-world/raw/master/images/entities.svg)

Once we have these two components running, they will not be able to communicate. The goal, at this point,
is just to make sure both components are running isolatedly on their own namespaces.


## Argo CD applications

An Argo CD application defines the `source` (Git Repository and path) and the `destination` (A Kubernetes cluster / namespace).
Basically Argo CD will try to keep the resources you have defined at your `source` synchronized with your `destination`.

There are multiple ways to define an Argo CD application. For example:

  * Using the `argocd` CLI
  * Defining an `Application` custom resource (apiVersion `argoproj.io/v1alpha1`), that is managed by Argo CD
  * Or using the Argo CD GUI (Console)

To keep things simple, we are going to use the **Argo CD GUI** to create the GitOps applications.

***Important:** In a real environment, you might consider defining an "App of apps". For more information please visit [https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/#app-of-apps-pattern](https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/#app-of-apps-pattern)***

## Creating an Argo CD application to the Frontend service

The Frontend service application is defined at this [particular GIT Repository](https://github.com/fgiorgetti/skupper-example-hello-world/tree/gitops)
at the **`gitops`** branch.

Go the the repository and explore the contents of **`/gitops/gitops/west/frontend`** directory.

The application itself is a simple HTTP application that attempts to invoke a hello world
API that is supposed to run at the east namespace.

To create it in Argo CD, follow these steps:

1. At the Argo CD console, click "+ NEW APP"

   ![](/images/20210129-new-app.png)
1. Enter the new application information:
   1. General:
      1. Application Name: **hello-world-frontend**
      1. Project: **default**
      1. Sync Policy: **Automatic**
      1. Sync Options:
         1. Check **Auto-create Namespace**
   1. Source:
      1. Repository URL: **https://github.com/fgiorgetti/skupper-example-hello-world.git**
      1. Revision: **gitops**
      1. Path: **gitops/west/frontend/**
   1. Destination:
      1. Cluster URL: **https://kubernetes.default.svc**
      1. Namespace: **west**
1. Click `CREATE`.

## Creating an Argo CD application to the Backend service

The Backend service application is defined at this [particular GIT Repository](https://github.com/fgiorgetti/skupper-example-hello-world/tree/gitops)
at the **`gitops`** branch.

Go the the repository and explore the contents of **`/gitops/gitops/east/backend`** directory.

This backend application provides a **`/api/hello`** endpoint that will be invoked by
the frontend application running at the `west` namespace.

### Understanding what is being deployed

Inspect the deployment descriptor for the `hello-world-backend` application that
is going to be deployed to the `east` namespace.

[/gitops/east/backend/01-deployment.yaml](https://github.com/fgiorgetti/skupper-example-hello-world/blob/0388bee7b89ba01402bc0edddcd99ec531b3a4e0/gitops/east/backend/01-deployment.yaml#L7-L9)

Note that is contains two annotations:

```
    skupper.io/port: "8080"
    skupper.io/proxy: "http"
```

The first one `skupper.io/port` defines the port of the deployment to be exposed
and the second one `skupper.io/proxy` defines the protocol of the service being
exposed.

This is what you need to add to the resource you want to expose, so when Skupper
is initialized in your namespace, it will create the respective service accordingly.
The new service will be replicated to other sites automatically.


To create it in Argo CD, follow these steps:

1. Back to the Argo CD console, click "+ NEW APP" again
1. Enter the new application information:
   1. General:
      1. Application Name: **hello-world-backend**
      1. Project: **default**
      1. Sync Policy: **Automatic**
      1. Sync Options:
         1. Check **Auto-create Namespace**
   1. Source:
      1. Repository URL: **https://github.com/fgiorgetti/skupper-example-hello-world.git**
      1. Revision: **gitops**
      1. Path: **gitops/east/backend/**
   1. Destination:
      1. Cluster URL: **https://kubernetes.default.svc**
      1. Namespace: **east**
1. Click `CREATE`.

## Validate applications are running

Verify the artifacts that have been created on both namespaces.

```
$ kubectl -n west get all
NAME                                        READY   STATUS    RESTARTS   AGE
pod/hello-world-frontend-55c84976c7-c6mq5   1/1     Running   0          31m

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-world-frontend   1/1     1            1           31m

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/hello-world-frontend-55c84976c7   1         1         1       31m
```

```
$ kubectl -n east get all
NAME                                      READY   STATUS    RESTARTS   AGE
pod/hello-world-backend-d8cf49cb7-h5vd4   1/1     Running   0          21m

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hello-world-backend   1/1     1            1           21m

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/hello-world-backend-d8cf49cb7   1         1         1       21m
```

At this point both the Frontend and Backend applications are running inside your
cluster and in different namespaces. But as said earlier, they cannot communicate
with each other.

Let's try to create another port-forward to the frontend service, so we can verify
it is up, but failing because it cannot reach the `backend` service.

```
$ kubectl -n west port-forward deployment/hello-world-frontend  8081:8080
```

Try opening your browser and access: `http://localhost:8081`.

You should see an error like:

```
Trouble! HTTPConnectionPool(host='hello-world-backend', port=8080): Max retries exceeded with url: /api/hello (Caused by NewConnectionError('<urllib3.connection.HTTPConnection object at 0x7f0d059d7dd0>: Failed to establish a new connection: [Errno -2] Name or service not known'))
```

The error above is an expected error, since both namespaces do not communicate... yet.

## Declaring a Skupper network in your git repository

First thing to do is ensure that we have Skupper running on both namespaces.
To do that, lets define another two Argo CD applications (one for each namespace).

### Creating a Skupper site on the west namespace

1. At the Argo CD console, click "+ NEW APP"
1. Enter the new application information:
   1. General:
      1. Application Name: **skupper-west**
      1. Project: **default**
      1. Sync Policy: **Automatic**
      1. Sync Options:
         1. Check **Auto-create Namespace**
   1. Source:
      1. Repository URL: **https://github.com/fgiorgetti/skupper-example-hello-world.git**
      1. Revision: **gitops**
      1. Path: **gitops/west/skupper/**
   1. Destination:
      1. Cluster URL: **https://kubernetes.default.svc**
      1. Namespace: **west**
1. Click `CREATE`.


### Creating a Skupper site on the east namespace

1. Back to the Argo CD console, click "+ NEW APP"
1. Enter the new application information:
   1. General:
      1. Application Name: **skupper-east**
      1. Project: **default**
      1. Sync Policy: **Automatic**
      1. Sync Options:
         1. Check **Auto-create Namespace**
   1. Source:
      1. Repository URL: **https://github.com/fgiorgetti/skupper-example-hello-world.git**
      1. Revision: **gitops**
      1. Path: **gitops/east/skupper/**
   1. Destination:
      1. Cluster URL: **https://kubernetes.default.svc**
      1. Namespace: **east**
1. Click `CREATE`.

### Verifying the Skupper network

Let's verify Skupper is running properly in your namespaces. But first, you might need to
download the `skupper` tool. Please visit the [Skupper releases page](https://github.com/skupperproject/skupper/releases)
and download the client for your operating system.

*Make sure to install it as `skupper` and make sure it is available in your PATH.*


#### Validating pods

```
$ kubectl -n west get pods
NAME                                         READY   STATUS    RESTARTS   AGE
hello-world-frontend-55c84976c7-c6mq5        1/1     Running   0          91m
skupper-router-79b9db88bb-r42cf              1/1     Running   0          19m
skupper-service-controller-b894b6554-gt64t   1/1     Running   0          19m
skupper-site-controller-fc56c7686-wtwwp      1/1     Running   0          19m
```

#### Validating skupper status

```
$ skupper -n west status
Skupper is enabled for namespace "west" with site name "skupper-west" in interior mode. It is not connected to any other sites. It has no exposed services.
```

*Repeat the same validation using the **east** namespace.*

### Creating a connection token to the west namespace

Next we need to create our Virtual Application Network (VAN) using Skupper
to allow communication with exposed services from all namespaces.

To do that, we must use the `skupper` tool to generate a connection token to
the `west` namespace.

```
$ skupper -n west token create /tmp/west.token.yaml
```

This token allows you to connect another site to Skupper running at the `west`
namespace. So it must be stored carefully.

In this demo, we are not storing tokens in our Git Repository, but if you plan
to do so, make sure you are using `git crypt` to avoid exposing your certificates.

### Connecting east namespace to the west namespace

As said above, we do not have the token in our sample Git Repository, so we must
manually connect the `east` namespace to the `west` namespace.

To do that, run:

```
$ skupper -n east link create /tmp/west.token.yaml
```

### Verify Skupper network is connected


After you have linked the two sites, you can monitor your network to ensure Skupper
network is connected. Run:

* From `west` namespace

```
$ skupper -n west status
Skupper is enabled for namespace "west" with site name "skupper-west" in interior mode. It is connected to 1 other site. It has 1 exposed service.

```

* From `east` namespace

```
$ skupper -n east status
Skupper is enabled for namespace "east" with site name "skupper-east" in interior mode. It is connected to 1 other site. It has 1 exposed service.
```

Now our Virtual Application Network is connected and the `hello-world-backend` deployment
has been exposed as a service and it is available on both namespaces.

## Testing the frontend application

To test the frontend application, lets run the port-forward to the `hello-world-frontend` deployment
one more time.

```
kubectl -n west port-forward deployment/hello-world-frontend 8081:8080
```

Now open your Browser and type: `http://localhost:8081`.
You should see a message like:

```
I am the frontend.  The backend says 'Hello from hello-world-backend-d8cf49cb7-h5vd4 (1)'.
```

Success! Now the Frontend application running at the `west` namespace can reach out
to the Backend application running at the `east` namespace through Skupper's exposed
service `hello-world-backend`.

I hope you might find this useful to help you setting up your GitOps operator and Skupper.
