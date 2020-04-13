---
name: Storage Migration Checklist (Short)
about: Checklist for Migrating Single Storage Root to New Storage Brick
title: 'Old storage root *??* to New storage root *??*'
labels: 'storage migration checklist'
assignees: ''

---

**Goal: Migrate This Storage Root Without Introducing New Errors**

- Use this template for a single storage root.
- If multiple roots will be migrated in one weekend, create a separate github issue from this template for each root being migrated.
  - provide a link here to the github uber issue for all roots being migrated.

- More info is available here _(please read before proceeding)_: https://github.com/sul-dlss/preservation_catalog/wiki/Storage-Migration---Additional-Information

- Keep an eye out for Honeybadger errors from preservation_catalog and from preservation_robots.
- Keep an eye out for failed prescat resque worker jobs.

## Audit Reports Before Cutover Weekend

Run all validation checks on Moabs and generate reports.  Note that error details change with different checks, so we want to run these checks sequentially, not simultaneously, and we want error reports generated after each check completes, before the next one starts.

### M2C (moab to catalog -- ensure everything on the disk is currently in the catalog)
- [ ] run on storage root: ```RAILS_ENV=production bundle exec rake prescat:audit:m2c[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] the run should be finished when all jobs in the `m2c` queue have been worked (queue is back down to 0)
- [ ] after M2C finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,m2c_b4]```
- [ ] note druids for each existing M2C error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] ? Ensure there is a github issue in preservation_catalog for each error/object (mult objects with same error can be in same github issue.)

### C2M (catalog to moab -- ensure everything in the catalog for that disk actually exists on the disk)
- [ ] run on storage root ```RAILS_ENV=production bundle exec rake prescat:audit:c2m[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] the run should be finished when all jobs in the `c2m` queue have been worked (queue is back down to 0)
- [ ] after C2M finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,c2m_b4]```
- [ ] note druids for each existing C2M error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] ? Ensure there is a github issue in preservation_catalog for each error/object (mult objects with same error can be in same github issue.)

### CV (checksum validation of all cataloged moabs)
- [ ] run on storage root ```RAILS_ENV=production bundle exec rake prescat:audit:cv[stor_root_name]```
  - [ ] requeue failed jobs / ensure no jobs failed via resque GUI https://preservation-catalog-prod-01.stanford.edu/resque/overview
  - [ ] the run should be finished when all jobs in the `checksum_validation` queue have been worked (queue is back down to 0)
- [ ] after CV finishes, generate report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,cv_b4]```
- [ ] note druids for each existing CV error (from report in /opt/app/pres/preservation_catalog/current/log/reports)
  - [ ] ? Ensure there is a github issue in preservation_catalog for each error/object (mult objects with same error can be in same github issue.)


##  During Cutover Weekend, After Service Shut Down

### List of Druids for Root

- [ ] get list of druids on storage root ```RAILS_ENV=production bundle exec rake prescat:reports:msr_druids[storage_root_name,druids_b4]```

### Final Validation Error Report

- [ ] generate final pre-cutover report for objects with error status ```RAILS_ENV=production bundle exec rake prescat:reports:msr_moab_audit_errors[stor_root_name,b4_cutover]```
  - If the pre-cutover reports listed above were run right before the migration was started (i.e. in the minutes/hours leading up to the migration), this final report may be unnecessary (though it couldn't hurt, and shouldn't take long to run).

### Update Affected Moabs In PresCat (after Migration)

- [ ] run rake migration task to tell prescat that Moabs have moved (should be addressed in Uber ticket)


## After Migration

### CV Error Checks After Migration

We have a list of druids that were on this root, and of objects from this root that had CV errors before the migration.

- [ ] determine which objects from the CV report for the new storage location pertain to this root.

- [ ] examine each existing CV_after error for this root

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


### M2C Error Checks After Migration

We have a list of druids that were on this root, and of objects from this root that had M2C errors before the migration.

- [ ] determine which objects from M2C report for the new storage location pertain to this root.

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
