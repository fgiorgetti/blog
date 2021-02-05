---
title: "Golang Bash Completion with Cobra API"
date: 2021-02-03T17:15:08-03:00
draft: false
categories: [example]
tags: [golang, bash, cobra]
---

In this post, I am going to share an example that demonstrates how to use bash completion with a Golang
application that uses [Cobra](https://github.com/spf13/cobra), a library to help writing Command Line Interface (CLI) apps.

## Source repository

You can find the sources mentioned in this example at the following [Git Repository](https://github.com/fgiorgetti/go-playground/tree/main/bashcomp).

## Pre-requisites

You must have the following packages (assuming you're on Linux) and
commands available:

* go (1.15+)
* bash
* bash-completion
* base64
* make

## The example application

The code in the repository above demonstrates a very basic (and, let's say, not so useful) application
called `bashcomp` that handles the following commands:

### hello

```
$ bashcomp hello Bash
Hello my dear Bash
```

### goodbye

```
$ bashcomp goodbye Bash
Goodbye fellow Bash
```

### thanks

```
$ bashcomp thanks to Bash
Thank you very much fellow Bash!

$ bashcomp thanks from Bash
Bash says Thank you!
```

### completion

```
$ bashcomp completion
...
... it will output a shell script you can save as a local file ...
...
```

## Autocomplete function

In order to make it easier to maintain the auto compete function, I have decided to keep it
in a separate script named `bash_completion.sh`.

This script offers completion support for the main options: `hello`, `goodbye`, `thanks` and `completion`.
In case you choose `thanks`, its allowed arguments will be offered, which are: `to` and `from`.

## How does it get bound to the bashcomp application

If you look at the `Makefile` file in the Git Repository link above, you can see
that I am associating the content of `bash_completion.sh` encoded as Base 64 with
`main.BashCompletionEncoded` variable that is defined at `bashcomp.go`. It all
happens at build time.

Why doing so? Because this way you can ship just your `bashcomp` binary file, and it
will be capable of generating the autocomplete shell script without the need to refer
to an external file or location.

## Validating autocomplete in action

* Let's clone the repository first

```bigquery
$ git clone https://github.com/fgiorgetti/go-playground.git
$ cd go-playground/bashcomp
```

* Now build the application

```bigquery
$ make
go build -ldflags "-X main.BashCompletionEncoded=`cat bash_completion.sh | base64 -w 0`" -o bashcomp bashcomp.go
./bashcomp completion > bashcomp.bash.inc

Now you must run: source bashcomp.bash.inc

... and make sure you have 'bashcomp' binary in your PATH
```

After `make` completes, you will find a `bashcomp` binary file as well as a
shell script named `bashcomp.bash.inc` (produced by `make`, which executed: `$ bashcomp completion`).


* Install `bashcomp` to your PATH

I am installing it to my local `${HOME}/bin` directory, which is defined as part
of my `PATH`. If you use a different location, feel free to adjust the next command accordingly.

```bigquery
$ install bashcomp ${HOME}/bin
```

* Sourcing the autocomplete script

Before autocomplete works in your `bash` session, you must source
the generated completion script by running:

```bigquery
$ source bashcomp.bash.inc
```

From now on, auto completion should work whenever you type:

`bashcomp <tab><tab>`

or even

`bashcomp thanks <tab><tab>`


That's all!

I hope you enjoyed and may have learned something interesting.