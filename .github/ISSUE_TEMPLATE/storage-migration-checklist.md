---
name: Storage Migration Checklist
about: Checklist for Migrating Single Storage Root to New Storage Brick
title: 'Old storage root *??* to New storage root *??*'
labels: 'storage migration checklist'
assignees: ''

---

**Goal: Migrate This Storage Root Without Introducing New Errors**

- Use this template for a single storage root.
- If multiple roots will be migrated in one weekend, create a separate github issue from this template for each root being migrated.
  - provide a link here to the github issue for the other root's migration.

Note that many old storage roots will migrate to each of the new storage bricks, so not all weekend migrations will be introducing a new storage brick into the ecosystem.


## Note about shared_configs PRs

The instructions below recommend PRs for shared_configs changes.  It would be great to get those PRs reviewed before merging via the usual process, but if no one is available to review them, _use your judgment_.  If you find yourself in a situation where you have to merge your own shared_configs PR for the migration not to stall waiting for review, that's fine, just see if you can cross check your work thoroughly yourself.  E.g., try copying and pasting the path for a new storage root entry from the shared_configs PR, and then `ls`ing it from a pres cat VM to make sure it doesn't contain typos.

## Notes & advice for running validation and reporting commands

* Reporting and validation rake tasks should be run from a production preservation catalog VM.  It may be easiest to always use `preservation-catalog-prod-01` for consistency.
* The rake tasks take the storage root name (`stor_root_name` used as placeholder in the instructions below).  Storage root names are the shorter more readable aliases for the full paths to the storage roots (i.e. the keys in `storage_root_map` in [shared configs](https://github.com/sul-dlss/shared_configs/blob/preservation-catalog-prod/config/settings/production.yml), used for the `name` field in the [`moab_storage_roots` table](https://github.com/sul-dlss/preservation_catalog/blob/master/db/README.md)).
* The validation `rake` tasks are queueing jobs to do the validation actual work:
  * This still might take tens of minutes on large storage roots, so you may want to run those `rake` tasks from a `screen` session.
  * The `rake` task will report errors queueing the jobs, but not the results of the jobs.
  * The `rake` task will likely finish well before the jobs it queues are all finished.


## Week Before Cutover Weekend

Ops will be ensuring all the data on the old root has been migrated to the new brick.

Run all validation checks on Moabs and generate reports.  Note that error details change with different checks, so we want to run these checks sequentially, not simultaneously, and we want error reports generated after each check completes, before the next one starts.

#### M2C (moab to catalog -- ensure everything on the disk is currently in the catalog)
- [ ] run on storage root: ```RAILS_ENV=production bundle exec rake prescat:audit:m2c[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] the run should be finished when all jobs in the `m2c` queue have been worked (queue is back down to 0)
- [ ] after M2C finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,m2c_b4]```
- [ ] note druids for each existing M2C error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] Ensure there is a github issue in preservation_catalog for each error/object (mult objects with same error can be in same github issue.)

#### C2M (catalog to moab -- ensure everything in the catalog for that disk actually exists on the disk)
- [ ] run on storage root ```RAILS_ENV=production bundle exec rake prescat:audit:c2m[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] the run should be finished when all jobs in the `c2m` queue have been worked (queue is back down to 0)
- [ ] after C2M finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,c2m_b4]```
- [ ] note druids for each existing C2M error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] Ensure there is a github issue in preservation_catalog for each error/object (mult objects with same error can be in same github issue.)

#### CV (checksum validation of all cataloged moabs)
- [ ] run on storage root ```RAILS_ENV=production bundle exec rake prescat:audit:cv[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] the run should be finished when all jobs in the `checksum_validation` queue have been worked (queue is back down to 0)
- [ ] after CV finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,cv_b4]```
- [ ] note druids for each existing CV error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] Ensure there is a github issue in preservation_catalog for each error/object (mult objects with same error can be in same github issue.)


##  During Cutover Weekend

- [ ] generate final pre-cutover report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,b4_cutover]```
  - If the pre-cutover reports listed above were run right before the migration was started (i.e. in the minutes/hours leading up to the migration), this final report may be unnecessary (though it couldn't hurt, and shouldn't take long to run).
  - Note that running the report will not actually trigger any auditing, it'll just query the database for the status info that was set during the most recently run audits (that's why the report should run quickly).
- Keep an eye out for Honeybadger errors from preservation_catalog and from preservation_robots.
  - preservation-catalog: https://app.honeybadger.io/projects/54415/faults?q=-is%3Aresolved+-is%3Aignored
  - preservation_robots: https://app.honeybadger.io/projects/55564/faults?q=-is%3Aresolved+-is%3Aignored

### Negotiate with Andrew/Julian as to how early on (Friday) you can do the Following:

- [ ] get list of druids on storage root ```RAILS_ENV=production bundle exec rake prescat:reports:msr_druids[storage_root_name,druids_b4]```

- [ ] (Ops) turn off nagios alerts for preservation_robots prod boxes

- **Shut Down Preservation Robots Workers**
  - [ ] look for running preservation robots workers in the resque GUI:  https://robot-console-prod.stanford.edu/workers
  - [ ] shut off the workers manually by killing (only) the `resque-pool-master` process (`hotswap` interferes with other cap resque commands)

    ```sh
    # from the preservation_robots project on your laptop:
    $ bundle exec cap prod ssh

    # once you're on the preservation-robots1-prod server:
    $ ksu
    ps -eaf | grep resque
    # look for line like this:
    # pres      1234     1  0 Feb18 ?        00:00:15 resque-pool-master[20200218172434]: managing [10204, 10207, 10210, 10214, 10219, 10223, 10228, 10235, 10239, 10242]
    kill -s QUIT [1234] # substitute the appropriate resque-pool-master pid, obviously
    ps -eaf | grep resque # confirm the workers aren't running
    ```
  - [ ] ensure there are no running preservation robots workers in the resque GUI:  https://robot-console-prod.stanford.edu/workers

- [ ] (Ops) turn off nagios alerts for accessioning workers

- **Shut Down Accessioning Robots Worker**
  - [ ] @suntzu or some other not-naomi person should document how to do this.
  - [ ] affected:  versioning of objects, creating contentMetadata, creating technicalMetadata, ...

- [ ] (Ops) turn off nagios alerts for preservation_catalog prod boxes

- **Shut Down Preservation Catalog Archival Workers, ReST API and weekend crons**
  - [ ] create a shared_configs PR (***to base branch `preservation-catalog-prod`***) that comments out all archive copy related workers (which create, deliver, and audit archival zips of moab version directories).

    `config/resque-pool.yml` should look like this:
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

    If you're not confident that CV and M2C will finish by Sunday evening, giving them more resque workers may help up to a point.  Note that CV requires CPU to generate checksums, so upping those workers could peg out the worker VMs.  Additionally, file reads require network bandwidth (because storage roots are mounted via NFS), and so may eventually hit IO limits.  Discuss with ops if this is a concern.

  - [ ] have someone merge shared_configs PR (if possible, see note at top)

  - [ ] for preservation-catalog repo, rebase `migration-weekend` branch on top of the latest `master`

      `migration-weekend` should be just like a fresh `git pull` of master, with 2 additional commits), like this:

      ```
      58c339b - (origin/migration-weekend, migration-weekend) comment out rest routes (56 minutes ago)
      9162475 - comment out weekend cron jobs (56 minutes ago)
      0ce2085 - (origin/master, master) xxxxxx (22 hours ago)
      ```

      Note that `/resque` route is still functional in the `migration-weekend` branch

  - [ ] force push the newly rebased `migration-weekend` branch back to github (necessary for deployment, which is done using the code as pushed to github)

  - [ ] deploy `migration-weekend` branch to prod

      ```sh
      bundle exec cap prod deploy
      ```

  - [ ] confirm there are no archival workers running via the resque GUI: https://preservation-catalog-prod-01.stanford.edu/resque/workers
    - archival workers are workers for the `zipmaker`, `zips_made`, `zip_endpoint_events`, `*_delivery`, `results_recorder`, `part_audit_*`, and `moab_replication_audit` queues.
  - [ ] confirm the ReST routes are not available (e.g. go to https://preservation-catalog-prod-01.stanford.edu/v1/objects/wr934ny6689)
    - [ ] the ReST routes are unavailable if `GET`ing them results in a 404 -- if they were active, the response would be an auth error due to lack of token, instead of a "not found"
  - [ ] confirm there are no weekend cron jobs, especially CV

      Note that cron jobs are deployed on preservation-catalog-prod-02 (technically there are also cron jobs defined on -04, but we're not concerned about them here).

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
- unmount the old storage root's NFS volume so that pres cat no longer has access to the contents, leaving empty `sdr2objects` and `deposit` directories in the path that previously mounted the storage root contents.  (this will make the contents of the old storage invisible to pres cat without deleting the files where they actually reside)
- more ops-y things
- notify us the data is now available in its new home.

### Back to the Devs After Ops Says Data Available

#### Confirm that the old storage root's NFS volume has been unmounted

The migrated moabs should no longer be visible in the old location (e.g., if migrating off of `services-disk02`, `/services-disk02/sdr2objects` should be present, but empty -- its moabs should only be available from the migration's target storage location).  This will prevent pres cat from seeing the same moab in two places, which is currently unsupported.

#### Tell PresCat About New Storage Root

- [ ] update shared_configs for prescat with the new storage root information

  - [ ] create a shared_configs PR (***to base branch `preservation-catalog-prod`***) that adjusts storage root information.

    `storage_root_map.default` in `config/settings/production.yml` should have the target storage location on the new brick named and added, and the old storage root entry removed

      ```yml
      storage_root_map:
        default:
          # services-disk02: '/services-disk02' # lines to be removed, left here for illustrative purposes
          # services-disk03: '/services-disk03'
          services-disk04: '/services-disk04'
          <snip>
          services-disk22: '/services-disk22'
      ```
  - [ ] have someone merge shared_configs PR (if possible, see note at top)

- [ ] use capistrano to make prescat aware of new shared_configs

    ```sh
    bundle exec cap prod shared_configs:update
    bundle exec cap prod passenger:restart
    ```

- [ ] if you added a new storage root (the first time migrating data to a particular new storage brick), you will need to add the root to the prescat db (run this from your laptop):

    ```sh
    bundle exec cap prod db_seed
    ```

    (yes, it's `db_seed` via capistrano)

#### Update Affected Moabs In PresCat

- [ ] run rake migration task to tell prescat that Moabs have moved (as with the reporting and auditing `rake` tasks, provide the storage root names, _not_ their full paths)
  - **NOTE** You should run this task in screen, as it can take a couple minutes, and you don't want to interrupt it in the middle.

    ```sh
    # from your laptop:
    $ bundle exec cap prod ssh

    # on the server, from 'current' directory:
    RAILS_ENV=production bundle exec rake prescat:migrate_storage_root[from,to]
    ```

#### CV after migration

  - [ ] confirm that CV workers for newly migrated objects are running via the resque GUI: https://preservation-catalog-prod-01.stanford.edu/resque/overview

    If you're not confident that CV can finish by Sunday evening, give it more resque workers via shared_configs PR https://github.com/sul-dlss/shared_configs/blob/preservation-catalog-stage/config/resque-pool.yml

    NOTE: if we have to trigger CV audits manually (i.e. the above doesn't automatically kick off workers), we will need to run CV for the list of druids on the new root, NOT the entire new storage brick (when there is more than one old root migrated to a single new storage brick.)  The list of druids is the 'druids_b4' report for the old storage root in /opt/app/pres/preservation_catalog/current/log/reports.  Running CV for a list of druids is documented in the prescat README.  When [testing the checklist](https://github.com/sul-dlss/preservation_catalog/issues/1420), CV jobs failed to queue automatically -- we suspect because CV had just been run on the druids in question, and the resque lock for de-duping jobs was still hanging around.

  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] watch for errors in Honeybadger
  - [ ] after CV finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,cv_after]```
  - [ ] diff cv_b4 report with cv_after report - the druids and statuses should match.
  - [ ] examine each existing CV_after error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
    - [ ] is it an EXISTING error (did this object have the same error before migration?  Check the appropriate cv_b4 error report)
      - [ ] Manual check at os level to compare files on new and old.

        Make sure the files contained in the source moab directories are the same as the files contained in the target moab directories (e.g. the list of enumerated files is the same, and the file contents on both sides produce the same respective md5 values)

        If not: work with Ops to perhaps do a manual re-copy of any Moabs on the target storage with new errors, compared to the source storage.

      - [ ] if files are "the same" in the old and new location, then this error can be ignored until after migration.
        - [ ] Ensure there is a github issue for the error/object in preservation_catalog (there should be, from a previous step!)
      - [ ] if files are NOT "the same" in the old and new location
        - [ ] Work with Ops to perhaps do a manual re-copy of the Moab's files from the source to the target storage
        - [ ] Re-run CV on this object (see README) to see if status changes to match cv_b4 report.
          - [ ] If not, PANIC.  (don't know what to do with these yet - will update this doc soon.)

    - [ ] is it a NEW error?  (the object did NOT have the same error before migration)
      - [ ] Work with Ops to perhaps do a manual re-copy of the Moab's files from the source to the target storage
      - [ ] Re-run CV on this object (see README) to see if status changes to 'ok'.
        - [ ] If not, PANIC.  (don't know what to do with these yet - will update this doc soon.)

  **IS ANYTHING TOO SCARY TO CONTINUE WITH MIGRATION?**  (e.g. lots of new errors)


#### M2C after migration

After CV has finished,

- [ ] run M2C on new storage root: ```RAILS_ENV=production bundle exec rake prescat:audit:m2c[stor_root_name]```

NOTE:  we may want to run druid lists rather than an entire new storage brick when there are more than a handful of old roots migrated to a single new storage brick.

  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview

M2C can keep running after cutover (since we know we have all druids from storage root in the catalog).  

Do **CHECK FOR M2C ERRORS while it's running** (run audit report) to see if anything surfaces (we hope not!)

Do check for honeybadger errors while audit validations are running

  - [ ] after M2C finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,m2c_after]```
  - [ ] diff m2c_b4 report with m2c_after report - the druids and statuses should match.
  - [ ] examine each existing M2C error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
    - [ ] is it a NEW error?  (check the appropriate m2c_b4 error report)
      - [ ] Work with Ops to perhaps do a manual re-copy of the Moab's files from the source to the target storage
      - [ ] Re-run M2C on this object (see README) to see if status changes to 'ok'.
        - [ ] If not, PANIC.  (don't know what to do with these yet - will update this doc soon.)

    - [ ] is it an EXISTING error (did this object have the same error before migration?  Check the appropriate m2c_b4 error report)
        Make sure the files contained in the source moab directories are the same as the files contained in the target moab directories (e.g. the list of enumerated files is the same, and the file contents on both sides produce the same respective md5 values)

      - [ ] if files are "the same" in the old and new location, then this error can be ignored until after migration.
        - [ ] Ensure there is a github issue in preservation_catalog for the error/object (there should be, from previous step!)
      - [ ] if files are NOT "the same" in the old and new location
        - [ ] Work with Ops to perhaps do a manual re-copy of the Moab's files from the source to the target storage
        - [ ] Re-run M2C on this object (see README) to see if status changes to match cv_b4 report.
          - [ ] If not, PANIC.  (don't know what to do with these yet - will update this doc soon.)

### After Migration Success

#### Restore Preservation Catalog Archival Workers, ReST API and weekend crons

  - [ ] create a shared_configs PR (***to base branch `preservation-catalog-prod`***) that reverts the worker changes made above, and keeps the new storage root config.

    `config/resque-pool.yml` should look like this:
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

  - [ ] have someone merge shared_configs PR (if possible, see note at top)

  - [ ] deploy `master` branch of preservation_catalog to prod

    ```sh
    bundle exec cap prod deploy
    ```

  - [ ] confirm there are archival workers running via the resque GUI: https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] confirm the ReST routes are available (e.g. go to https://preservation-catalog-prod-01.stanford.edu/v1/objects/wr934ny6689)
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

    `moab.storage_roots` in `config/environments/prod.yml`  should have the target storage location on the new brick added, and the old storage root entry removed

      ```yml
      moab:
        storage_roots:
          # - '/services-disk02' # lines to be removed, left here for illustrative purposes
          # - '/services-disk03'
          - '/services-disk04'
          <snip>
          - '/services-disk22'
      ```
  - [ ] have someone merge shared_configs PR (if possible, see note at top)

- [ ] deploy `master` branch of preservation_robots to use the new shared_configs and to turn the workers back on

    ```sh
    bundle exec cap prod deploy
    ```

  - [ ] confirm your capistrano logs show the shared_configs being updated

  - [ ] confirm there are preservation robots workers available via the resque GUI:  https://robot-console-prod.stanford.edu/workers

- [ ] (Ops) turn on nagios alerts for preservation_robots prod boxes

#### Update shared_configs for technical-metadata-service

- [ ] update shared_configs for technical-metadata-service with the new storage root information

  - [ ] create a shared_configs PR (***to base branch `dor-techmd-prod`***) that adjusts storage root information.

    `storage_root_map.default` in `config/settings/production.yml` should have the target storage location on the new brick named and added, and the old storage root entry removed

      ```yml
      storage_root_map:
        default:
          # services-disk02: '/services-disk02' # lines to be removed, left here for illustrative purposes
          # services-disk03: '/services-disk03'
          services-disk04: '/services-disk04'
          <snip>
          services-disk22: '/services-disk22'
      ```

  - [ ] deploy `master` branch of technical-metadata-service to use the new shared_configs

    ```sh
    bundle exec cap prod deploy
    ```

  - [ ] confirm your capistrano logs show the shared_configs being updated


## After Cutover Weekend

- [ ] when M2C is done, generate an error report and compare it with the `m2c_b4` error report for the migrated root.

- [ ] confirm migrated objects can be updated

- [ ] confirm new objects are flowing through preservation_robots steps and are being added to preservation_catalog

- [ ] watch for Honeybadger errors from preservation_robots and from preservation_catalog

- [ ] watch for preservationAuditWF errors (via Argo)
