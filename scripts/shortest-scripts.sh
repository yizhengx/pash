#!/bin/bash
# A bash script for finding the shortest scripts 
# From "Wicked Cool Shell Scripts", 2nd Ed., pg. 7
# +p.95 multiple sed
# +p.XX crawler
file /usr/bin/* | grep "shell script" | cut -d: -f1 | xargs wc -l | sort -n | head -15