# Project Guidelines

preservation_catalog (aka prescat or pres cat) is a Rails application that does the following for Stanford Digital Repository (SDR) objects:
* catalogs the existence, version, and last known preservation fixity status for each preserved copy of an accessioned SDR object.
* replicates copies to the cloud, from on prem copies that have passed fixity checking.
* audits on prem and cloud copies of archival artifacts for presence and data integrity.
  * As of May 2026, all on prem copies are regularly checked in full for fixity.  Cloud copies are checked for presence and expected minimum size, and there are plans to introduce fixity checking as part of future enhancement work.

## Architecture

Prefer putting complex domain logic in service classes. As much as is possible, model classes, job classes, and rake tasks should be thin wrappers for service class code that is well tested.

For command line tasks that require complex argument handling, prefer scripts in the bin directory that use OptionParser, instead of Rake tasks.

## Conventions

In the database, use foreign key constraints and unique indexes where possible.

Similarly, also use Rails ActiveRecord validations where possible to provide informative error messages, and _only_ where needed, to implement validation that cannot be adequately expressed as relational database constraints.

## Testing Notes

* When creating multiple, unique druids for the same spec, vary at least the first 2 characters and the last 2 characters.
* Prefer instance_doubles instead of doubles.
* For mocking, place allow statements in a before block and expect statements after the action is performed. Prefer testing argument (with) in expect; do not test in both allow and expect.
* Place "let" statements before "before "blocks.


## SDR object identifiers

Each object is identified by a unique "druid" (Digital Repository Unique Identifier).

Druids are stored **without** the `druid:` prefix in the database. The pattern is enforced with an ActiveRecord format validator. The `druid-tools` gem provides `DruidTools::Druid` for validation and path generation based on other app configuration.

Druids should match the pattern "^[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}$", e.g., "bc123df4567".
