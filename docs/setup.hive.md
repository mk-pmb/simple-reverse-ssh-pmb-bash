
Setup
=====

Creating a hive and group
-------------------------

A "hive" is just a subdirectory in the repo toplevel whose name is a number.
It's the port number that your drone will send in its CONNECT request.
The "group" is a subdirectory inside the hive.
The hostname given in the CONNECT request is split into the labels,
the list is reversed, and used as path prefix for the session files.


#### Session directory path example

For a drone requesting `CONNECT lab01.example.edu:1 HTTP/1.1`,
served by a socat child process with process ID 8899,
connected on 2025-03-18, 14:27:51 UTC,
the control socket will be `1/edu/example/lab01/250318-142751-8899.sock`.


#### Missing path segments

* A request for a non-existent hive is unrecoverable, so
  the drone will be considered unauthorized, and dropped.
* For the group part though, there is a mechanism to help you host the session
  directories on tmpfs: At each directory step in the path, if it's a dead
  symlink, the server will try and create a directory at the symlink target,
  also creating parent directories if required.
  * Hosting the session directories on tmpfs is especially useful when running
    on a NAS where it would be wasteful to spin up a magnetic disk just to
    create files that after reboot would be useless anyway.
  * However, this comes at the cost of potential memory exhaustion if you use
    an unlimited RAM disk and have evil people on your LAN.
    Thus, consider creating a dedicated, size-limited RAM disk.
* If any part of the path is not a directory
  even after the potential symlink revival attempt,
  the drone will be considered unauthorized, and dropped.







