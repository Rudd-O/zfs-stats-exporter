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
    expr: '1 - (zfs_pool_avail_bytes / zfs_pool_avail_bytes) > 0.95'
    for: 2m
    annotations:
      summary: '{{ $labels.zpool }} in {{ $labels.instance }} at {{ $value }} capacity'
```

## Tips on reducing disk usage and cardinality

### No need for available / total bytes per dataset

The metric `zfs_dataset_avail_bytes` repeats what `zfs_pool_avail_bytes` already carries,
but for every file system.  This is convenient for querying, but if you can use queries
to perform some intelligent label replacing, you don't need it.

You can drop it with some Prometheus metric relabel configuration:

```yaml
  metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'zfs_dataset_avail_bytes'
     action: drop
```

The same applies to the metric `zfs_dataset_size_bytes`, carried by `zfs_pool_size_bytes`.
Eliminate it with:

```yaml
  metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'zfs_dataset_size_bytes'
     action: drop
```

Would this complicate queries like _largest snapshots in a pool_?  Slightly, but
you can still perform them.  Here's a sample query computing the size of each
snapshot among the top ten:

```
sort_desc(
  topk(
    10,
    label_replace(zfs_dataset_used_bytes{type="snapshot"}, "zpool", "$1", "dataset", "([^/]+).*")
    / on(zpool, instance) group_left() zfs_pool_size_bytes
  )
  * on(zpool, instance) group_left() zfs_pool_size_bytes
)
```

What's the trick here?  The trick is that we're dynamically adding a label
`zpool` to the series of the used bytes, based on the name of the dataset,
then we're using `group_left()` on the `zpool` and `instance` labels to
obtain the size of the pool, against which we divide the value, giving us
a percentage of usage.  Finally, after selecting the largest datasets by
usage percentage, we select the top ten and then we multiply again by the
size of the pool to get the size in bytes for the dataset.

### Is it necessary for your use case to have the refer bytes per snapshot?

If you don't need that information, and you're fine with just having the top-level
refer bytes value for the file system or zvol, then you can drop the value:

```yaml
  metric_relabel_configs:
  - source_labels: [__name__, type]
    regex: 'zfs_dataset_refer_bytes;snapshot'
     action: drop
```

You can keep the `zfs_dataset_used_bytes` metric for snapshot size calculation.

### Do you need the compress ratio per snapshot?

Most likely not.  Drop them with:

```yaml
  metric_relabel_configs:
  - source_labels: [__name__, type]
    regex: 'zfs_dataset_compress_ratio;snapshot'
     action: drop
```
