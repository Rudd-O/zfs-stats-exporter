# ZFS stats exporter

This is a simple Prometheus exporter that provides the following information
about a system's ZFS pools and datasets:

* available bytes per dataset, (but it's really per pool)
* size, refer and used bytes per dataset
* available bytes per pool
* size of pool in bytes
* error count
* healthy (flag 1/0)
* pool scrub progress

The node exporter already provides some useful ZFS metrics.  This program
aims to supplement those.

## Usage

Run the program `zfs-stats-exporter` with a single positive integer number
as argument, representing the port on which the exporter will listen.

A sample systemd unit is provided to run the exporter as a service.

## Installation

You can make an RPM package to install on your system by using `make rpm`
in this repository's checked-out folder.  The package will be deposited in
the current directory.

It's also possible to install manually by using `make install`.

## Suggested alerting rules

For unhealthy pools:

```
  - alert: PoolUnhealthy
    expr: zfs_pool_healthy == 0
    for: 10s
    annotations:
      summary: '{{ $labels.zpool }} in {{ $labels.instance }} is degraded or faulted'
  - alert: PoolErrored
    expr: zfs_pool_errors_total > 0
    for: 10s
    annotations:
      summary: '{{ $labels.zpool }} in {{ $labels.instance }} has had {{ $value }} {{ $labels.class }} errors'
```

For low pool disk space:

```
  - alert: PoolSpaceLow
    expr: '1 - (zfs_dataset_avail_bytes{dataset !~ ".*/.*"} / zfs_dataset_size_bytes{dataset !~ ".*/.*"}) > 0.95'
    for: 2m
    annotations:
      summary: '{{ $labels.dataset }} in {{ $labels.instance }} at {{ $value }} capacity'
```
