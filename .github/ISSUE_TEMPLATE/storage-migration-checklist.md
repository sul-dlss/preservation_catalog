---
name: Storage Migration Checklist
about: Checklist for Migrating Single Storage Root to New Storage Brick
title: 'Old Storage Root **??** to New Storage Root **??**'
labels: 'storage migration checklist'
assignees: ''

---

**Goal: Migrate This Storage Root Without Introducing New Errors**

- Use this template for a single storage root.
- If multiple roots will be migrated in one weekend, create a separate github issue from this template for each root being migrated.
  - provide a link here to the github issue for the other root's migration.

Note that many old storage roots will migrate to each of the new storage bricks, so not all weekend migrations will be introducing a new storage brick into the ecosystem.

## Week Before Cutover Weekend

Ops will be ensuring all the data on the old root has been migrated to the new brick.

Run all validation checks on Moabs and generate reports.  Note that error details change with different checks, so we want to run these checks sequentially, not simultaneously, and we want error reports generated after each check completes, before the next one starts.

#### M2C
- [ ] run on storage root: ```RAILS_ENV=production bundle exec rake prescat:audit:m2c[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
- [ ] after M2C finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_audit_errors[stor_root_name,m2c_b4]```
- [ ] examine each existing M2C error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] if fixable ... fix it
    - [ ] re-run M2C on any fixed objects to ensure object is now valid
  - [ ] can it be ignored until after migration?
  - [ ] other?
- [ ] generate new report for objects with error status if any errors were fixed

#### C2M
- [ ] run on storage root ```RAILS_ENV=production bundle exec rake prescat:audit:c2m[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
- [ ] after C2M finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_audit_errors[stor_root_name,c2m_b4]```
- [ ] examine each existing C2M error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] if fixable ... fix it
    - [ ] re-run C2M on any fixed objects to ensure object is now valid
  - [ ] can it be ignored until after migration?
  - [ ] other?
- [ ] generate new report for objects with error status if any errors were fixed

#### CV
- [ ] run on storage root ```RAILS_ENV=production bundle exec rake prescat:audit:cv[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
- [ ] after CV finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_audit_errors[stor_root_name,cv_b4]```
- [ ] examine each existing CV error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] if fixable ... fix it
    - [ ] re-run CV on any fixed objects to ensure object is now valid
  - [ ] can it be ignored until after migration?
  - [ ] other?
- [ ] generate new report for objects with error status if any errors were fixed


##  During Cutover Weekend

- [ ] generate final pre-cutover report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_audit_errors[stor_root_name,b4_cutover]```

### Negotiate with Andrew/Julian as to how early on Friday you can do the Following:

- [ ] get list of druids on storage root ```RAILS_ENV=production bundle exec rake prescat:reports:msr_druids[storage_root_name,druids_b4]```

- [ ] (Ops) turn off nagios alerts for preservation_robots prod boxes

- Shut Down Preservation Robots Workers
  - [ ] look for running preservation robots workers in the resque GUI:  https://robot-console-prod.stanford.edu/workers
  - [ ] shut off the workers manually (`hotswap` interferes with other cap resque commands)

    ```sh
    # from your laptop:
    $ bundle exec cap prod ssh

    # on the server:
    $ ksu
    ps -eaf | grep resque
    # look for line like this:
    # pres      9862     1  0 Feb18 ?        00:00:15 resque-pool-master[20200218172434]: managing [10204, 10207, 10210, 10214, 10219, 10223, 10228, 10235, 10239, 10242]
    kill -s QUIT [9862] # substitute the appropriate pid, obviously
    ps -eaf | grep resque # ensure the workers aren't runnint
    ```
  - [ ] ensure there are no running preservation robots workers in the resque GUI:  https://robot-console-prod.stanford.edu/workers

- [ ] (Ops) turn off nagios alerts for preservation_catalog prod boxes

- Shut Down Preservation Catalog Archival Workers, ReST API and weekend crons
  - [ ] create a shared_configs PR (***to base branch `preservation-catalog-prod`***) that comments out all archive copy related workers.

    `shared_configs/config/resque-pool.yml` should look like this:
    ```yml
    c2m: 6
    checksum_validation: 6
    # ibm_us_south_delivery: 6
    m2c: 6
    # moab_replication_audit: 3
    # part_audit_aws_s3_east_1: 3
    # part_audit_aws_s3_west_2: 3
    # part_audit_ibm_us_south: 3
    # results_recorder: 6
    # s3_us_east_1_delivery: 6
    # s3_us_west_2_delivery: 6
    # zip_endpoint_events: 6
    # zipmaker: 6
    # zips_made: 6
    ```

    If you're not confident that CV and M2C will finish by Sunday evening, give them more resque workers.  Note that CV does require RAM to generate checksums, so upping those workers could peg out the worker VMs.

  - [ ] have someone merge shared_configs PR

  - [ ] for preservation-catalog repo, rebase `migration-weekend` branch on top of master

      `migration-weekend` should be just like a fresh `git pull` of master, with 2 additional commits), like this:

      ```
      58c339b - (origin/migration-weekend, migration-weekend) comment out rest routes (56 minutes ago)
      9162475 - comment out weekend cron jobs (56 minutes ago)
      0ce2085 - (origin/master, master) xxxxxx (22 hours ago)
      ```

      Note that `/resque` route is still functional in `migration-weekend` branch

  - [ ] deploy `migration-weekend` branch to prod

      ```sh
      bundle exec cap prod deploy
      ```

  - [ ] confirm there are no archival workers running via the resque GUI: https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] confirm the ReST routes are not available (e.g. go to https://preservation-catalog-prod-01.stanford.edu/objects/wr934ny6689)
  - [ ] confirm there are no weekend cron jobs, especially CV

      Note that cron jobs are deployed on preservation-catalog-prod-02.

      ```sh
      bundle exec cap -z preservation-catalog-prod-02.stanford.edu prod ssh
      crontab -l
      ```

      there should not be an uncommented line with `validate_expired_checksums!` in it.

  - [ ] notify Ops that preservation-catalog is ready for their final steps

### Ops Runs with the Baton

Ops will now perform such tasks as the following:
- final backup of prescat database
- final migration of data from old storage root to new
- migrated content moved to final location on new brick (see #1376 )
- apply puppet PR to add new brick to preservation robots and prescat as needed
- more ops-y things
- notify us the data is now available in its new home.

### Back to the Devs After Ops Notification

#### Tell PresCat About New Storage Root

- [ ] update shared_configs for prescat with the new storage root information

  - [ ] create a shared_configs PR (***to base branch `preservation-catalog-prod`***) that adjusts storage root information.

    `shared_configs/config/settings/production.yml` storage root map should have the new brick and remove the old, migrated root

      ```yml
      storage_root_map:
        default:
          # services-disk02: '/services-disk02' - these lines will be removed, here for illustrative purposes
          # services-disk03: '/services-disk03'
          services-disk04: '/services-disk04'
          <snip>
          services-disk22: '/services-disk22'
      ```
  - [ ] have someone merge shared_configs PR

- [ ] use capistrano to make prescat aware of new shared_configs

    ```sh
    bundle exec cap prod shared_configs:update
    bundle exec cap prod passenger:restart
    ```

- [ ] if you added a new storage root (the first time migrating data to a particular new storage brick), you will need to add the root to the prescat db (run this from your laptop):

    ```sh
    bundle exec cap prod db:seed
    ```

#### Update Affected Moabs In PresCat

- [ ] run rake migration task to tell prescat that Moabs have moved

    ```sh
    # from your laptop:
    $ bundle exec cap prod ssh

    # on the server:
    RAILS_ENV=production rake prescat:migrate_storage_root[from,to]
    ```

#### CV after migration

  - [ ] confirm that CV workers for newly migrated objects are running via the resque GUI: https://preservation-catalog-prod-01.stanford.edu/resque/overview

    If you're not confident that CV can finish by Sunday evening, give it more resque workers via shared_configs PR https://github.com/sul-dlss/shared_configs/blob/preservation-catalog-stage/config/resque-pool.yml

    NOTE: if we have to trigger CV audits manually, we may want to run it for a list of druids rather than an entire new storage brick when there are more than a handful of old roots migrated to a single new storage brick.

  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] after CV finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_audit_errors[stor_root_name,cv_after]```
  - [ ] examine each existing CV error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
    - [ ] is it a NEW error, or was this object having the same error before migration?  (check the appropriate cv_b4 error report)
      - [ ] if NEW and fixable ... fix it
        - [ ] re-run CV on any fixed objects to ensure object is now valid
    - [ ] Did moab validation run?  If not: manual check at os level to compare files on new and old.

      Make sure the files contained in the source moab directories are the same as the files contained in the target moab directories (e.g. the list of enumerated files is the same, and the file contents on both sides produce the same respective md5 values)

      If not: work with Ops to perhaps do a manual re-copy of any Moabs on the target storage with new errors, compared to the source storage.

    - [ ] can it be ignored until after migration?
    - [ ] other?

  - [ ] generate new report for objects with error status if any errors were fixed

  - [ ] diff report after move vs. report before content migrated
    - [ ] ensure we don't have new errors that weren't on old storage

  **IS ANYTHING TOO SCARY TO CONTINUE WITH MIGRATION?**  (e.g. lots of new errors)


#### M2C after migration

After CV has finished,

- [ ] run M2C on new storage root: ```RAILS_ENV=production bundle exec rake prescat:audit:m2c[stor_root_name]```

NOTE:  we may want to run druid lists rather than an entire new storage brick when there are more than a handful of old roots migrated to a single new storage brick.

  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview

M2C can keep running after cutover (since we know we have all druids from storage root in the catalog).  

Do **CHECK FOR M2C ERRORS while it's running** (run audit report) to see if anything surfaces (we hope not!)

  - [ ] after M2C finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_audit_errors[stor_root_name,m2c_after]```
  - [ ] examine each existing M2C error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
    - [ ] is it a NEW error, or was this object having the same error before migration?  (check the appropriate m2c_b4 error report)
    - [ ] if NEW and fixable ... fix it
      - [ ] re-run M2C on any fixed objects to ensure object is now valid
    - [ ] can it be ignored until after migration?
    - [ ] other?
    - [ ] generate new report for objects with error status if any errors were fixed

### After Migration Success

#### Restore Preservation Catalog Archival Workers, ReST API and weekend crons

  - [ ] create a shared_configs PR (***to base branch `preservation-catalog-prod`***) that reverts the worker changes made above, and keeps the new storage root config.

    `shared_configs/config/resque-pool.yml` should look like this:
    ```yml
    c2m: 6
    checksum_validation: 6
    ibm_us_south_delivery: 6
    m2c: 6
    moab_replication_audit: 3
    part_audit_aws_s3_east_1: 3
    part_audit_aws_s3_west_2: 3
    part_audit_ibm_us_south: 3
    results_recorder: 6
    s3_us_east_1_delivery: 6
    s3_us_west_2_delivery: 6
    zip_endpoint_events: 6
    zipmaker: 6
    zips_made: 6
    ```

  - [ ] have someone merge shared_configs PR

  - [ ] deploy `master` branch of preservation_catalog to prod

    ```sh
    bundle exec cap prod deploy
    ```

  - [ ] confirm there are archival workers running via the resque GUI: https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] confirm the ReST routes are available (e.g. go to https://preservation-catalog-prod-01.stanford.edu/objects/wr934ny6689)
  - [ ] confirm there are weekend cron jobs, especially CV

      Note that cron jobs are deployed on preservation-catalog-prod-02.

      ```sh
      bundle exec cap -z preservation-catalog-prod-02.stanford.edu prod ssh
      crontab -l
      ```

      there should be a line with `validate_expired_checksums!` in it.

- [ ] (Ops) turn on nagios alerts for preservation_catalog prod boxes

#### Restore Preservation Robots Workers

- update shared_configs for preservation robots with the new storage root information

  - [ ] create a shared_configs PR (***to base branch `preservation_robots_prod`***) that adjusts storage root information.

    `shared_configs/config/settings/production.yml` storage root map should have the new brick and remove the old, migrated root

      ```yml
      storage_root_map:
        default:
          # services-disk02: '/services-disk02' - these lines will be removed, here for illustrative purposes
          # services-disk03: '/services-disk03'
          services-disk04: '/services-disk04'
          <snip>
          services-disk22: '/services-disk22'
      ```
  - [ ] have someone merge shared_configs PR

- [ ] deploy `master` branch of preservation_robots to use the new shared_configs and to turn the workers back on

    ```sh
    bundle exec cap prod deploy
    ```

  - [ ] confirm there are preservation robots workers available via the resque GUI:  https://robot-console-prod.stanford.edu/workers

- [ ] (Ops) turn on nagios alerts for preservation_robots prod boxes

## After Cutover Weekend

- [ ] when M2C is done, generate an error report and compare it with the `m2c_b4` error report for the migrated root.

- [ ] confirm migrated objects can be updated

- [ ] confirm new objects are flowing through preservation_robots steps and are being added to preservation_catalog

- [ ] watch for Honeybadger errors from preservation_robots and from preservation_catalog

- [ ] watch for preservationAuditWF errors (via Argo)
