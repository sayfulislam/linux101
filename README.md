# Linux Shell Scripts for DevOps Exams

Ten practice scripts, one for each exam topic. Every script holds many small tasks. You run one task at a time.

## How to use

```bash
chmod +x *.sh                 # make the scripts runnable (one time)
./01_basics.sh                # no task name = show the list of tasks
./01_basics.sh factorial 5    # run one task
sudo ./03_users_permissions.sh create_user dev1 developers   # some tasks need root
```

Every script works the same way: `./script.sh <task> [values]`.

## Script list

| # | File | Topic | Needs root? |
|---|------|-------|-------------|
| 1 | `01_basics.sh` | Variables, if/else, loops, functions, arrays, strings, trap | No |
| 2 | `02_files_text.sh` | find, grep, sed, awk, sort, uniq, rename | No |
| 3 | `03_users_permissions.sh` | Users, groups, chmod, chown, sudo, SSH keys | Most tasks |
| 4 | `04_processes_services.sh` | ps, kill, systemctl, journalctl, systemd unit | Some tasks |
| 5 | `05_system_monitoring.sh` | CPU, memory, disk, load, alerts, health report | No |
| 6 | `06_networking.sh` | ping, ports, curl, DNS, SSL, SSH, firewall | Only `firewall` |
| 7 | `07_logs.sh` | Log analysis, failed logins, log rotation | Only `failed_ssh` |
| 8 | `08_backup_cron.sh` | tar, rsync, database dump, cron, lock file, retry | Depends on folders |
| 9 | `09_git_cicd.sh` | Git, version tags, pipeline, deploy, rollback | Only `install_pkgs` |
| 10 | `10_docker_k8s.sh` | Docker and Kubernetes tasks | Docker access |

---

## 1. Basics — `01_basics.sh`

```bash
./01_basics.sh vars a b c          # special variables: $0 $# $* $$
./01_basics.sh check_number -7     # positive/negative, even/odd
./01_basics.sh check_path /etc/passwd
./01_basics.sh loops               # for, while, until, read a file
./01_basics.sh arrays
./01_basics.sh calc 6 x 7          # use x for multiply
./01_basics.sh factorial 5
./01_basics.sh fibonacci 10
./01_basics.sh strings "Hello World"
./01_basics.sh trap_demo           # clean up temp files on exit
```

**Must know**

| Item | Meaning |
|------|---------|
| `$0` `$1` `$#` `$@` | script name, first value, count of values, all values |
| `$?` | exit code of the last command (0 = success) |
| `$$` | process ID of the script |
| `${var:-default}` | use `default` if `var` is empty |
| `[[ -f x ]]` `-d` `-r` `-w` `-x` `-s` | file, folder, readable, writable, runnable, not empty |
| `-eq -ne -lt -le -gt -ge` | number tests inside `[[ ]]` |
| `set -euo pipefail` | stop on error, on unset variable, on failed pipe |

## 2. Files and text — `02_files_text.sh`

```bash
./02_files_text.sh count notes.txt
./02_files_text.sh biggest /var 10
./02_files_text.sh old_files /tmp 30            # list files older than 30 days
./02_files_text.sh old_files /tmp 30 delete     # delete them
./02_files_text.sh search "error" /var/log
./02_files_text.sh replace old new config.txt   # keeps config.txt.bak
./02_files_text.sh word_freq notes.txt 5
./02_files_text.sh csv_report staff.csv         # name,department,salary
./02_files_text.sh rename_ext ./docs txt md
./02_files_text.sh clean_lines notes.txt
./02_files_text.sh dup_files ./photos
```

**Must know**

```bash
grep -rn "word" dir/         # search in all files, show line numbers
grep -c "word" file          # count matching lines
sed -n '5,10p' file          # print lines 5 to 10
sed -i 's/old/new/g' file    # replace in the file
awk -F: '{ print $1 }' file  # print first column, ":" is the separator
awk '{ s += $3 } END { print s }' file    # add up column 3
sort file | uniq -c | sort -rn            # count repeats, biggest first
find . -name "*.log" -mtime +7 -delete    # delete logs older than 7 days
```

## 3. Users and permissions — `03_users_permissions.sh`

```bash
sudo ./03_users_permissions.sh create_user dev1 developers
sudo ./03_users_permissions.sh bulk_users users.txt     # lines like: dev2,developers
sudo ./03_users_permissions.sh lock_user dev1
./03_users_permissions.sh list_users
sudo ./03_users_permissions.sh audit
sudo ./03_users_permissions.sh shared_dir /srv/team developers
sudo ./03_users_permissions.sh fix_web_perms /var/www/html www-data
./03_users_permissions.sh risky_files /usr
./03_users_permissions.sh explain_perm 754
```

**Must know**

| Number | Meaning |
|--------|---------|
| 4 / 2 / 1 | read / write / run |
| `755` | owner all, others read and run (folders, scripts) |
| `644` | owner read and write, others read (normal files) |
| `600` | only the owner (keys, secrets) |
| `2770` | setgid: new files keep the folder's group |
| `/etc/passwd` `/etc/shadow` `/etc/group` | users, passwords, groups |

## 4. Processes and services — `04_processes_services.sh`

```bash
./04_processes_services.sh top_cpu 5
./04_processes_services.sh top_mem 5
./04_processes_services.sh is_running nginx
./04_processes_services.sh kill_proc myapp 10      # polite stop, then force
./04_processes_services.sh zombies
./04_processes_services.sh port_owner 80
sudo ./04_processes_services.sh watch_service nginx   # restart if down
./04_processes_services.sh services_status ssh nginx docker
./04_processes_services.sh failed
sudo ./04_processes_services.sh make_service myapp "/opt/myapp/run.sh" appuser
```

**Must know**

| Signal | Meaning |
|--------|---------|
| `kill -15` (TERM) | ask the process to stop (try this first) |
| `kill -9` (KILL) | force stop, no cleanup |
| `kill -1` (HUP) | reload settings |

```bash
systemctl start|stop|restart|status nginx
systemctl enable --now nginx       # start now and on every boot
journalctl -u nginx -n 50 -f       # last 50 log lines, keep following
```

## 5. Monitoring — `05_system_monitoring.sh`

```bash
./05_system_monitoring.sh sysinfo
./05_system_monitoring.sh disk_alert 80      # warn at 80% full
./05_system_monitoring.sh cpu_alert 90
./05_system_monitoring.sh mem_alert 90
./05_system_monitoring.sh load_alert
./05_system_monitoring.sh disk_hogs /var 10
./05_system_monitoring.sh report
./05_system_monitoring.sh notify 85 admin@example.com
./05_system_monitoring.sh watch_log 5 12 /tmp/usage.csv   # every 5s, 12 times
```

**Must know:** `df -h` (disk space), `du -sh dir` (folder size), `free -h` (memory), `uptime` (load), `top`, `vmstat 1`, `df -i` (inodes). Load higher than the number of CPUs means the server is too busy.

## 6. Networking — `06_networking.sh`

```bash
./06_networking.sh ping_hosts hosts.txt
./06_networking.sh port_check db.local 5432
./06_networking.sh port_scan 10.0.0.5 22 80 443
./06_networking.sh url_check https://example.com 200
./06_networking.sh urls_check urls.txt
./06_networking.sh wait_for localhost 8080 30
./06_networking.sh dns example.com
./06_networking.sh ssl_days example.com 443 30
./06_networking.sh netinfo
./06_networking.sh ssh_run hosts.txt "uptime"
sudo ./06_networking.sh firewall
```

**Must know ports:** 22 SSH, 25 SMTP, 53 DNS, 80 HTTP, 443 HTTPS, 3306 MySQL, 5432 PostgreSQL, 6379 Redis, 27017 MongoDB.

```bash
ss -ltnp                                    # listening ports and their programs
curl -s -o /dev/null -w '%{http_code}' URL  # only the HTTP status code
ip a ; ip route                             # addresses and routes
```

## 7. Logs — `07_logs.sh`

Start with sample logs so you can practice anywhere:

```bash
./07_logs.sh sample                 # makes /tmp/samplelogs/access.log and app.log
L=/tmp/samplelogs
./07_logs.sh levels $L/app.log
./07_logs.sh top_errors $L/app.log 5
./07_logs.sh top_ips $L/access.log 5
./07_logs.sh status_codes $L/access.log
./07_logs.sh top_urls $L/access.log
./07_logs.sh not_found $L/access.log
./07_logs.sh per_hour $L/access.log
./07_logs.sh summary $L/access.log
./07_logs.sh between $L/app.log "2026-01-10 10:00" "2026-01-10 11:00"
sudo ./07_logs.sh failed_ssh
./07_logs.sh rotate /var/log/myapp.log 5 10    # keep 5, rotate at 10 MB
./07_logs.sh logrotate_conf "/var/log/myapp/*.log" myapp
```

**Must know:** in a web access log, column 1 is the IP, column 7 is the page, column 9 is the status code. The pattern `awk '{print $1}' | sort | uniq -c | sort -rn | head` answers most "top N" questions.

## 8. Backup and cron — `08_backup_cron.sh`

```bash
./08_backup_cron.sh backup /var/www /backup 7        # keep 7 days
./08_backup_cron.sh restore /backup/www_2026.tar.gz /tmp/restore
./08_backup_cron.sh incremental /var/www /backup/incr
./08_backup_cron.sh sync_dir /var/www/ user@host:/backup/www/
./08_backup_cron.sh db_backup mysql shopdb /backup/db
./08_backup_cron.sh with_lock ./08_backup_cron.sh backup /var/www /backup
./08_backup_cron.sh retry 3 5 curl -fsS https://example.com
./08_backup_cron.sh add_cron "0 2 * * *" "/opt/08_backup_cron.sh backup /var/www /backup >> /var/log/backup.log 2>&1"
./08_backup_cron.sh list_cron
./08_backup_cron.sh cron_help
```

**Must know cron format:** `minute hour day-of-month month day-of-week command`

| Schedule | Meaning |
|----------|---------|
| `*/5 * * * *` | every 5 minutes |
| `0 2 * * *` | every day at 02:00 |
| `0 9 * * 1-5` | Monday to Friday at 09:00 |
| `0 0 1 * *` | first day of each month |

`tar -czf` makes a backup, `tar -xzf` opens it, `tar -tzf` lists what is inside.

## 9. Git and CI/CD — `09_git_cicd.sh`

Run these inside a git project folder.

```bash
./09_git_cicd.sh quick_push "fix login bug"
./09_git_cicd.sh repo_info
./09_git_cicd.sh clean_branches main
./09_git_cicd.sh bump_version minor          # v1.2.3 -> v1.3.0
./09_git_cicd.sh pull_all ~/projects
./09_git_cicd.sh install_hook                # blocks commits with passwords
./09_git_cicd.sh pipeline myapp ./dist       # check, build, test, package
./09_git_cicd.sh deploy ./dist/myapp_abc123.tar.gz /opt/app 5
./09_git_cicd.sh rollback /opt/app
./09_git_cicd.sh safe_deploy ./dist/myapp_abc123.tar.gz http://localhost/health
./09_git_cicd.sh check_env DB_HOST DB_USER
sudo ./09_git_cicd.sh install_pkgs git curl jq
```

**Must know:** a pipeline runs stages in order (build → test → package → deploy) and stops at the first failure. The deploy here puts each version in its own folder and points the `current` link at the newest one, so going back is just moving the link.

## 10. Docker and Kubernetes — `10_docker_k8s.sh`

```bash
./10_docker_k8s.sh d_build myapp .
./10_docker_k8s.sh d_push myapp myreg.azurecr.io latest
./10_docker_k8s.sh d_redeploy web nginx:latest 8080:80
./10_docker_k8s.sh d_watch web
./10_docker_k8s.sh d_cleanup 168h
./10_docker_k8s.sh d_stats
./10_docker_k8s.sh d_logs_errors web 1h
./10_docker_k8s.sh d_volume_backup dbdata /backup
./10_docker_k8s.sh d_compose_update /opt/stack

./10_docker_k8s.sh k_bad_pods
./10_docker_k8s.sh k_summary
./10_docker_k8s.sh k_deploy web myreg/web:v2 production
./10_docker_k8s.sh k_scale web 3 production
./10_docker_k8s.sh k_debug web-7d9f-abc production
./10_docker_k8s.sh k_backup production ./k8s-backup
```

**Must know**

```bash
docker ps -a ; docker logs -f NAME ; docker exec -it NAME sh
docker system prune -af                       # remove all unused data
kubectl get pods -A ; kubectl describe pod P ; kubectl logs P
kubectl rollout status|undo deployment/NAME   # watch or undo a deploy
```

---

## Exam tips

1. Start every script with `#!/usr/bin/env bash` and `set -euo pipefail`.
2. Always put quotes around variables: `"$file"`, not `$file`.
3. Check the input first, and print a clear message when it is wrong.
4. Use exit code `0` for success and any other number for failure.
5. Use `local` for variables inside functions.
6. Send error messages to stderr: `echo "error" >&2`.
7. Test for syntax mistakes without running: `bash -n script.sh`.
8. See each command as it runs: `bash -x script.sh`.
9. Never put passwords inside a script. Use environment variables or a config file with `600` permission.

## Notes

- Tested on Ubuntu 24.04 with bash 5. Tasks for users, systemd, firewall, Docker and Kubernetes need those tools on your machine and were only checked for syntax here.
- Tasks that delete things (`old_files ... delete`, `d_cleanup`, `delete_user`, `cleanup`) do not ask first. Try them on test data before real servers.
