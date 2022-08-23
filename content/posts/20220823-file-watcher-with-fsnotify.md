---
title: "File Watcher With Fsnotify"
date: 2022-08-23T00:21:47-03:00
draft: false
---


Sometimes we need to watch for modifications in specific locations in
the filesystem, reacting to them differently.

As an example, an alert could be triggered if a specific file is modified
or a backup procedure could start as new files are created into specific
directories.

There are several tools and libraries to help doing that, but since I am
evaluating libraries in Go, I have decided to play with [fsnotify](https://github.com/fsnotify/fsnotify) and write a bit about it.


## fsnotify

It is a library written in Go that uses https://pkg.go.dev/golang.org/x/sys instead of
https://pkg.go.dev/syscall (from the standard library).

Fsnotify is supported on Linux, macOS, Windows and other operating systems.

With fsnotify you can create a `Watcher` instance that will emit a notification `Event`
for all files or directories (not recursively) added to it.

## Goal

Define a simple interface that provides a common mechanism for reacting to
changes notified against a specific file or directory.

Basically we will a pass specific location to be monitored by `fsnotify`.

This location can be an existing file, directory or even a new location in
the file system that may still not yet exist.

## Quick start

First thing we need to know is how to use the Watcher provided by fsnotify.
Code must import `github.com/fsnotify/fsnotify` and create a `fsnotify.Watcher` instance.

```go
watcher, err := fsnotify.NewWatcher()
```

After that you must add target files or directories to watch, like:

```go
err = watcher.Add(filename)
```

One important thing to mention here is that you must pass an existing file
or directory to be watched.

If you pass an invalid filename, fsnotify will report an error saying:
"`no such file or directory`".

To get around that, our implementation will also validate if the given file
or directory exists and otherwise it will try to add the named file to the
Watcher instance till it returns no error.

The notification events are sent to a channel named `Events` in the `Watcher`
instance and it has a property named `Op` that represents a file operation.

To validate the correct operation being notified you have to perform a bitwise
**`&`** (**AND**) operation against fsnotify generalized operations and validate
that the result matches it. As an example, to validate if a given event notification
refers to a new file or directory being created you can do:

```go
event.Op&fsnotify.Create == fsnotify.Create
```

With that we know what are the basics to write our own interface that helps reacting
to file system modifications more easily.

```go
type FSChangeHandler interface {
	OnCreate(string)
	OnUpdate(string)
	OnRemove(string)
}
```

We can customize how to react to certain events more easily and leave the communication
with `fsnotify` to be handled by an internal component.

In order to achieve that, the sample code will offer the following function:

```go
func NewWatcher(name string, stopCh chan bool, handler FSChangeHandler) error
```

Then you can use it as you need and simply provide multiple implementations to react
to specific events differently.

## Solution

### watcher.go

Here we have the NewWatcher function that uses watchCreated to wait for new file
or directory to be created and it will use the `FSChangeHandler` interface to notify
events accordignly.

```go
package watcher

import (
	"log"
	"os"
	"time"

	"github.com/fsnotify/fsnotify"
)

type FSChangeHandler interface {
	OnCreate(string)
	OnUpdate(string)
	OnRemove(string)
}

func watchCreated(watcher *fsnotify.Watcher, name string) {
	log.Printf("-> waiting for %s to exist", name)
	go func() {
		ticker := time.Tick(time.Second)
		for {
			select {
			case <-ticker:
				if err := watcher.Add(name); err == nil {
					log.Printf("-> now it exists: %s", name)
					return
				}
			}
		}
	}()
	return
}

func NewWatcher(name string, stopCh chan bool, handler FSChangeHandler) error {
	log.Printf("Creating watcher for: %s", name)
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}

	if _, err := os.Stat(name); err != nil && os.IsNotExist(err) {
		watchCreated(watcher, name)
	} else {
		watcher.Add(name)
	}

	go func() {
		for {
			select {
			case event := <-watcher.Events:
				switch {
				// useful for new files when watching directories
				case event.Op&fsnotify.Create == fsnotify.Create:
					handler.OnCreate(event.Name)
				case event.Op&fsnotify.Write == fsnotify.Write:
					handler.OnUpdate(event.Name)
				case event.Op&fsnotify.Remove == fsnotify.Remove:
					handler.OnRemove(event.Name)
					// object being watched removed, watch for it to show up again
					if event.Name == name {
						watcher.Remove(name)
						watchCreated(watcher, name)
					}
				}
			case <-stopCh:
				log.Printf("Done watching: %s", name)
				watcher.Close()
				return
			}
		}
	}()

	return nil
}
```

### fw.go

Here is a sample usage of the watcher presented earlier.
It provides a `FSChangeHandler` implementation that simply displays
the event type that has just been triggered and the filename.

```go
package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/fgiorgetti/go-playground/filewatcher/pkg/watcher"
)

type MyHandler struct {
}

func (m *MyHandler) OnCreate(name string) {
	log.Printf("File has been created: %s", name)
}

func (m *MyHandler) OnUpdate(name string) {
	log.Printf("File has been updated: %s", name)
}

func (m *MyHandler) OnRemove(name string) {
	log.Printf("File has been removed: %s", name)
}

func main() {
	stopCh := make(chan bool)
	if len(os.Args) != 2 {
		log.Fatalf("Use: %s file_or_directory", os.Args[0])
	}
	fileOrDir := os.Args[1]
	err := watcher.NewWatcher(fileOrDir, stopCh, &MyHandler{})
	if err != nil {
		log.Fatalf("Error creating watcher: %v", err)
	}

	// var done string
	fmt.Println("Press ENTER when done")
	_, _ = fmt.Scanln()
	close(stopCh)
	time.Sleep(time.Second)
}
```

### Running

To run it you must pass a single target file to be watched.
Remember it may or may not exist.

In a separate terminal you can play with modifications to the respective file.

Once you're done with it, just press ENTER in the terminal where the watcher
is running.

Example:

```shell
go run fw.go /tmp/sample-location
```

It will show you something like:

```shell
2022/08/23 12:26:52 Creating watcher for: /tmp/sample-location
2022/08/23 12:26:52 -> waiting for /tmp/sample-location to exist
Press ENTER when done
```

In another terminal you can create a file and add more content to it, like:

```shell
echo "some data" >> /tmp/sample-location
echo "some more data" >> /tmp/sample-location
```

Then in the main terminal you will see:

```shell
2022/08/23 12:27:07 -> now it exists: /tmp/sample-location
2022/08/23 12:28:40 File has been updated: /tmp/sample-location
```

Remove the file now:

```shell
rm /tmp/sample-location
```

And in the main terminal you should see:

```shell
2022/08/23 12:29:56 File has been removed: /tmp/sample-location
2022/08/23 12:29:56 -> waiting for /tmp/sample-location to exist
```

Next, create the target `/tmp/sample-location` as a directory and
create a file inside it with some sample content:

```shell
mkdir /tmp/sample-location
echo "some data" >> /tmp/sample-location/file1
```

You should see:

```shell
2022/08/23 12:31:18 -> now it exists: /tmp/sample-location
2022/08/23 12:31:40 File has been created: /tmp/sample-location/file1
2022/08/23 12:31:40 File has been updated: /tmp/sample-location/file1
```

I hope you find it useful.

## System information

FSNotify v1.5.4
OS: Fedora 36
Go: 1.19

## References

* [fsnotify source code](https://github.com/fsnotify/fsnotify/tree/v1.5.4)
* [fsnotify documentation](https://pkg.go.dev/github.com/fsnotify/fsnotify)
* [source code used here](https://github.com/fgiorgetti/go-playground/tree/main/filewatcher)
