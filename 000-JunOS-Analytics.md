# Introduction

This document describes how to collect analytics data from JunOS (e.g. interface statistics like bytes received) and visualise them with [Grafana](https://grafana.com/).

I'm using Ubuntu 16.04 running LXD in my lab. Each machine runs as a Ubuntu 16.04 container.

# Overview

The analytics data is sent by the JunOS analytics services. The data is received by the Python script [gpb2influx](https://github.com/m3ccanico/gpb2influx). The script writes the data to InfluxDB. Grafana reads the data from InfluxDB and creates the graphs.

# Configuration

## JunOS

I assume you have access to a JunOS devices. I've tested the below configuration with an MX5 and JunOS 16.1R6.7.

The configuration consists of three parts. The stream server defines where the data is sent to. The export profile defines the format, the local IP and port, and the frequency. Finally, the sensor ties the export profile to a server and selects the data source. In this these the interface counter of logical interfaces with a name that starts with *ge-*.

```
set services analytics streaming-server StreamServer remote-address 10.0.0.21
set services analytics streaming-server StreamServer remote-port 50001

set services analytics export-profile ExportProfile local-address 10.0.0.20
set services analytics export-profile ExportProfile local-port 50001
set services analytics export-profile ExportProfile reporting-rate 5
set services analytics export-profile ExportProfile format gpb

set services analytics sensor Sensor server-name StreamServer
set services analytics sensor Sensor export-name ExportProfile
set services analytics sensor Sensor resource /junos/system/linecard/interface/logical/usage/
set services analytics sensor Sensor resource-filter ge-.*
```

I chose five seconds as the export interval as I felt that refreshing the graph in Grafana every 5 seconds is sufficient. The version of JunOS I use in this lab supports reporting rates up to every 2 seconds.

## Python scripts (gbp2influx)

I couldn't find an existing daemon like [Telegraf](https://github.com/influxdata/telegraf) to receive the GPB data from JunOS and write it to [InfluxDB](https://www.influxdata.com/). Therefore, I chose to write a few lines of Python to do that for me. The code can be found here [gpb2influx](https://github.com/m3ccanico/gpb2influx).

The configuration of the listening port and the InfluxDB parameters are constants near the top of the script.

The script writes the following measurements:
* throughput_in (octet counter)
* throughput_out (octet counter)
* tail_drop_packets (packet counter, added up across all interface queues)
* red_drop_packets (packet counter, added up across all interface queues)

An alternative to this approach would have been to either write an InfluxDB plugin that receives the analytics data (that would probably the right approach for a production setup) or to use [OpenNTI](https://github.com/Juniper/open-nti) (I felt OpenNTI did too much else that I didn't needed).

## InfluxDB

Go here for [instructions how to install InfluxDB](https://portal.influxdata.com/downloads).

Once InfluxDB was running, I only had to create a database for the analytics data:

```
influx
CREATE DATABASE throughput
```

Check if data is written:
```
USE throughput
SELECT * FROM throughput_in LIMIT 5
```

## Grafana

Go here for [instructions how to install Grafana](https://grafana.com/grafana/download).

Create variables:
* Host `SHOW TAG VALUES WITH KEY = "host"`
* Interface `SHOW TAG VALUES WITH KEY = "interface" WHERE host='$host'`
Create graph:
* There is some math required to graph the counters. `NON_NEGATIVE_DERIVATIVE` calculates the rate of change. The result is multiplied by 8 to show bits instead of bytes.

[Grafana Graph JSON](https://github.com/m3ccanico/blog/blob/master/000/grafana.json)

# Discussion

## Streaming Analytics vs classic monitoring (i.e. SNMP)

There are several advantages of using streaming telemetry over classical network monitoring by SNMP:
* Fewer resources required on the network device. The device does not need to "react" to SNMP queries. Consequently it does not need to list to SNMP queries (i.e. run a server) and parse the query. Instead the device just constantly streams the collected data. 
* There are also fewer resources required on the server. There is no constant polling required.

The disadvantage is that this form of telemetry is not as well established as SNMP. Almost any network device can be queried by SNMP and almost any network monitoring solution supports SNMP. Streaming telemetry on the other hand is device and vendor specific. However, most vendor use industry standards like GPB or JSON to send the data. This often means it is possible to "massage" the data into the required format.