# Introduction

This document describes how to collect analytics data from a LXC container host running LXD through daemon's API and cgroup. The collected data is visualised with [Grafana](https://grafana.com/).

![Dashboard](https://github.com/m3ccanico/blog/blob/master/001/dashboard.png)

# Problem

Without adequate visibility into the resource usage of the containers, it is difficult to limit resources for them, find containers with run-away processes, or establish resouce baselines.

# Options

## Command line

```
lxc info cntr01
```

This gives me only a current and very basic view of the resources used by one container. I cannot compare the resource usage of different containers and cannot see past resource usage.

Interestingly, the command knows how to map the host network interfaces to the container. 

## cgroup and proc

The CPU load can be read from cgroups like `/sys/fs/cgroup/cpu/lxc/cntr01/cpuacct.stat` and the memory usage from `/sys/fs/cgroup/memory/lxc/cntr01/memory.usage_in_bytes`. The network traffic can be read from `/proc/net/dev`. However, its not easily possible to map the network interface names (e.g. veth9MT339) to a specific container.

An alternative to reading `/proc/net/dev` in the host is reading the same file within the container's namespace. Once in the container's namespace, it will only show the interfaces available to the container. For a way how to do that with Python, you can go to [Anthony Arnaud's collectd plugin for LXC]( https://github.com/aarnaud/collectd-lxc/blob/master/collectd_lxc.py)

## Telegraf

Telegraf has a cgroup plugin that can read specific values and write the results to InfluxDB. However, the cgroup plugin is not very flexible in the way the data is written. For example, it will tag the values with the whole path (e.g. `/sys/fs/cgroup/cpu/lxc/cntr01/cpuacct.stat`) which makes legends in corresponding graphs (e.g. in Grafana) harder to read.

## LXD REST API

Another option is offered by LXD itself. The daemon has a [REST API](https://github.com/lxc/lxd/blob/master/doc/rest-api.md#10containersnamestate) that provides access to CPU, disk, and memory usage. It also provides the current interface counters. There are existing API clients for Go and Python ([pylxd](https://github.com/lxc/pylxd)).

During my test, I've found that pylxd didn't implement the state API. Further, I've found that the state API didn't returned the correct CPU counters.

# Design

The script runs every 10 seconds. For each run it collects the memory and network usage from LXD through API calls and the CPU usage through the corresponding cgroups. Once collected, the values are written to InfluxDB tagged with the host and container name.

# Implementation

The implementation of the Python scrip can be found here: [lxd2influx](https://github.com/m3ccanico/lxd2influx).

## InfluxDB

Go here for [instructions how to install InfluxDB](https://portal.influxdata.com/downloads).

Once InfluxDB was running, I only had to create a database for the analytics data:

```
influx
CREATE DATABASE lxd
```

Check if data is written:
```
USE lxd
SHOW SERIES
```

## Grafana

Go here for [instructions how to install Grafana](https://grafana.com/grafana/download).

The graf can be found here: [Grafana Graph JSON](https://github.com/m3ccanico/blog/blob/master/001/grafana-lxd.json)

