---
title: "Purpose"
date: 2025-11-05
draft: true
tags: []
---


Start tracking some of my favorite commands

## Off to the races
```
ps -waux                    # wide, all users, user format, background
df -h                       # Disk Space - human readable
ls -latr                    # list dir contents, dir details, reverse by time
watch -n 5 {{command}}      # execute a command every 5 seconds
htop                        # better version of top, system metrics
(un)set                     # review, set and unset ENV variables
echo $?                     # show last exit status
netstat -tulnp              # all listening ports and pid
lsof -i -P -n               # all listeing ports and pid
which {{command}}           # what is the path to the command
locate                      # why bother with find
grep -r "text" /path/       # search in files
scp                         # secure copy
ssh                         # secure shell, tunnel, proxy
diff -y                     # side by side
rpm -aq                     # show me all the packages
dpkg --list                 # show me all the packages
ip addr                     # show me the IP
whereis                     # fuzzy search for stuff on system, directories for apps and binaries
tail -f /var/log/file       # stream a log file
service {{name}} status     # I'm old, I will use it until systemctl wins
du -sh /* | sort -h         # where is that big file?


## Maybe I'll use these more someday
```
find / -name "filename" 2>/dev/null  # Find files
ripgrep
iostat -x 1
tldr
journalctl -u [service]
```
## GIT stuff

git pull
git checkout -b feature/short-but-descriptive
git status
git add
git commit -m "log commit message"
git push -u


