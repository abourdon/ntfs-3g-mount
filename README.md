# NTFS-3G mount utils

(Re-)Mount all or specified NTFS drives on an OSX environment by using the [NTFS-3G driver](https://github.com/osxfuse/osxfuse/wiki/NTFS-3G) to enable read-write support.

## Prerequisites

Have macFuse & NTFS-3G installed. More information [here](https://github.com/osxfuse/osxfuse/wiki/NTFS-3G#installation)

## How to use

Mount or remount all NTFS drives currently available:
```sh
$ sudo ./ntfs-3g-mount
```

Mount or remount specific NTFS drives currently available:
```bash
$ sudo ./ntfs-3g-mount 'VOLUME NAME 1' 'VOLUME NAME 2'
```

Unmount all NTFS drives currently mounted:
```bash
$ sudo ./ntfs-3g-mount -u
```

Unmount specific NTFS drives currently mounted:
```bash
$ sudo ./ntfs-3g-mount -u 'VOLUME NAME 1' 'VOLUME NAME 2'
```