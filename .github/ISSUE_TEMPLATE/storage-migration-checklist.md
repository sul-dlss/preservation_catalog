---
name: Storage Migration Checklist
about: Checklist for Migrating Storage roots from 6220 and 8040 to new storage bricks
title: Old Storage Root(s) ____ to New Storage Root ____
labels: ''
assignees: ''

---

## Old Storage Root(s) ____ to New Storage Root ____

## Before Cutover Weekend
### Devs

### Ops


##  During Cutover Weekend
### Devs

### Ops

## After Migration Success
- [ ] shared_configs PR:  want new root and archival workers back
    - [ ] shared_configs PR merged
- [ ] deploy master branch; ensure it picks up shared_configs with archival workers and new root
- [ ] confirm:  all redis workers available; cron jobs are all in crontab, ReST routes avail
- [ ] ops: turn on all nagios alerts for prescat boxes
- [ ] turn on pres robot workers  ```cap deploy resque:pool:hotswap```
- [ ] ops: turn on nagios alerts for preservation_robots

## After Cutover Weekend

M2C can keep running after cutover (since we know we have all druids from storage root in the catalog)
