#!/usr/bin/python2.7
# b'@' = 0x40 = decimal 64 = the FD number to be shared.
import socket as s;s.sendmsg(1,'',[(s.SOL_SOCKET,s.SCM_RIGHTS,b'@')])
