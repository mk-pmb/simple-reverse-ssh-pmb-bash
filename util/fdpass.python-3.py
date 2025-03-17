#!/usr/bin/python3
# b'@' = 0x40 = decimal 64 = the FD number to be shared.
import socket as s;s.fromfd(1).sendmsg('',[(s.SOL_SOCKET,s.SCM_RIGHTS,b'@')])
