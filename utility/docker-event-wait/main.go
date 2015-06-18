package main

import (
    "github.com/samalba/dockerclient"
    "time"
    "os"
)

// Callback used to listen to Docker's events
func eventCallback(event *dockerclient.Event, ec chan error, args ...interface{}) {
  os.Exit(0)
}

func main() {
    // Init the client
    docker, _ := dockerclient.NewDockerClient("unix:///var/run/docker.sock", nil)

    // Listen to events
    docker.StartMonitorEvents(eventCallback, nil)

    // Hold the execution to look at the events coming
    time.Sleep(3600 * time.Second)
}
