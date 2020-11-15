---
title: "Listing files and folders sorted by size"
date: 2020-11-15T17:10:00+02:00
draft: false
---

## Sort files and directories by size on disk

The following command sorts files and directories in descending order by their
disk usage:

```bash
du -hs * | sort -rh
```

### Explanation

`du` summarizes disk usage of files, and for directories it summarizes them
recursively. The `-s` option tells `du` to display "only a total for each
argument". Without it, `du` also displays recursively the sizes of each nested
directory. So for the following file structure

```
$ tree .
.
├── dir1
│   ├── dir11
│   │   └── file
│   ├── dir12
│   │   └── file
│   └── file
├── dir2
│   └── file
├── file1
├── file2
├── file3
└── file4
```

`du` without `-s` would output the following

```
$ du -h * 
260K    dir1/dir11
516K    dir1/dir12
908K    dir1
260K    dir2
16K     file1
32K     file2
1.0M    file3
64K     file4
```

And `-h` options makes the sizes human readable rather than in bytes. So `du`
without `-h` would output the following

```
$ du -s *
908     dir1
260     dir2
16      file1
32      file2
1024    file3
64      file4
```

#### `sort`

`sort` utility sorts lines from standard input. The `-r` options tells it to
reverse the result, i.e., sort in descending order. And the `-h` option tells it
to interpret human readable file size, i.e., understand that 1G is larger then
10K.
