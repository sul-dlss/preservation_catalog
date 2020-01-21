[![Build Status](https://travis-ci.org/sul-dlss/preservation_catalog.svg?branch=master)](https://travis-ci.org/sul-dlss/preservation_catalog)
[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/preservation_catalog/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/preservation_catalog?branch=master)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_catalog)

# README

Rails application to track, audit and replicate archival artifacts associated with SDR objects.

## Table of Contents

* [Getting Started](#getting-started)
* [Usage Instructions](#usage-instructions)
    * [Moab to Catalog](#m2c) (M2C) existence/version check
    * [Catalog to Moab](#c2m) (C2M) existence/version check
    * [Checksum Validation](#cv) (CV)
    * [Seed the catalog](#seed-the-catalog-with-data-about-the-moabs-on-the-storage-roots-the-catalog-tracks----presumes-rake-dbseed-already-performed)
* [Development](#development)
    * [Dockerized Development](#docker)
* [Deploying](#deploying)
* [API](#api)

## Getting Started

### Installing dependencies

Use the docker-compose to start the dependencies (PostgreSQL and Redis)
```sh
docker-compose up -d db redis
```

### Configuring The database

Run this script:
```sh
./bin/rails db:reset
RAILS_ENV=test ./bin/rails db:seed
```

# Usage Instructions

### Note: We are using the whenever gem for writing and deploying cron jobs. M2C, C2M, and CV are all scheduled using the whenever gem. You can view our schedule at [Schedule](config/schedule.rb)

## General Info

- Rake and console tasks must be run from the root directory of the project, with whatever `RAILS_ENV` is appropriate.

- You can monitor the progress of most tasks by tailing `log/production.log` (or task specific log), checking the Resque dashboard or by querying the database. The tasks for large storage_roots can take a while -- check [the repo wiki for stats](https://github.com/sul-dlss/preservation_catalog/wiki) on the timing of past runs (and some suggested overview queries). Profiling will add some overhead.

- Tasks that use asynchronous workers will execute on any of the eligible worker pool systems for that job.  Therefore, do not expect all the results to show in the logs of the machine that enqueued the jobs!

- Because large tasks can take days when run over all storage roots, consider running in a [screen session](http://thingsilearned.com/2009/05/26/gnu-screen-super-basic-tutorial/) so you don't need to keep your connection open but can still see the output.

As an alternative to `screen`, you can also run tasks in the background using `nohup` so the invoked command is not killed when you exist your session. Output that would've gone to stdout is instead redirected to a file called `nohup.out`, or you can redirect the output explicitly.  For example:

```sh
RAILS_ENV=production nohup bundle exec ...
```

### Rake Tasks

- Note: If the rake task takes multiple arguments, DO NOT put a space in between the commas.

- Rake tasks will have the form:

```sh
RAILS_ENV=production bundle exec rake ...
```

### Rails Console

The application's most powerful functionality is available via `rails console`.  Open it (for the appropriate environment) like:

```sh
RAILS_ENV=production bundle exec rails console
```

## <a name="m2c"/>Moab to Catalog (M2C) existence/version check

In console, first locate a `MoabStorageRoot`, then call `m2c_check!` to enqueue M2C jobs for that root.
The actual checks for `m2c_check!` are performed asynchronously by worker processes.

### Single Root
```ruby
msr = MoabStorageRoot.find_by!(storage_location: '/path/to/storage')
msr.m2c_check!
```

### All Roots
```ruby
MoabStorageRoot.find_each { |msr| msr.m2c_check! }
```

### Single Druid
To M2C a single druid synchronously, in console:
```ruby
Audit::MoabToCatalog.check_existence_for_druid('jj925bx9565')
```

### Druid List
For a predetermined list of druids, a convenience wrapper for the above command is `check_existence_for_druid_list`.

- The parameter is the file path of a CSV file listing the druids.
  - The first column of the csv should contain druids, without prefix.
  - File should not contain headers.

```ruby
Audit::MoabToCatalog.check_existence_for_druid_list('/file/path/to/your/csv/druid_list.csv')
```

Note: it should not typically be necessary to serialize a list of druids to CSV.  Just iterate over them and use the "Single Druid" approach.

## <a name="c2m"/>Catalog to Moab (C2M) existence/version check

Note: C2M uses the `Audit::CatalogToMoab` asynchronously via workers on the `:c2m` queue.

- Given a catalog entry for an online moab, ensure that the online moab exists and that the catalog version matches the online moab version.

- You will need to identify a moab storage_root (e.g. with path from settings/development.yml) and optionally provide a date threshold.

- The (date/timestamp) argument is a threshold: it will run the check on all catalog entries which last had a version check BEFORE the argument. You can use string format like '2018-01-22 22:54:48 UTC' or ActiveRecord Date/Time expressions like `1.week.ago`.  The default is anything not checked since **right now**.

These C2M examples use a rails console, like: `RAILS_ENV=production bundle exec rails console`

### Single Root

This enqueues work for all the objects associated with the first `MoabStorageRoot` in the database, then the last:

```ruby
MoabStorageRoot.first.c2m_check!
MoabStorageRoot.last.c2m_check!
```

This enqueues work from a given root not checked in the past 3 days.

```ruby
msr = MoabStorageRoot.find_by!(storage_location: '/path/to/storage')
msr.c2m_check!(3.days.ago)
```

### All Roots
This enqueues work from **all** roots similarly.
```ruby
MoabStorageRoot.find_each { |msr| msr.c2m_check!(3.days.ago) }
```

## <a name="cv"/>Checksum Validation (CV)
- Parse all `manifestInventory.xml` and most recent `signatureCatalog.xml` for stored checksums and verify against computed checksums.
- To run the tasks below, give the name of the storage root (e.g. from `settings/development.yml`)

Note: CV jobs that are asynchronous means that their execution happens in other processes (including on other systems).

### Single Root
From console, this queues objects on the named storage root for asynchronous CV:
```ruby
msr = MoabStorageRoot.find_by!(name: 'fixture_sr3')
msr.validate_expired_checksums!
```
### All Roots
This is also asynchronous, for all roots:
```ruby
MoabStorageRoot.find_each { |msr| msr.validate_expired_checksums! }
```

### Single Druid
Synchronously:
```ruby
Audit::Checksum.validate_druid(druid)
```

### Druid List
- Give the file path of the csv as the parameter. The first column of the csv should contain druids, without the prefix, and contain no headers.

In console:
```ruby
Audit::Checksum.validate_list_of_druids('/file/path/to/your/csv/druid_list.csv')
```

### Druids with a particular status on a particular storage root

For example, if you wish to run CV on all the "validity_unknown" druids on storage root 15, from console:

```ruby
Audit::Checksum.validate_status_root(:validity_unknown, :services-disk15)
```

[Valid status strings](https://github.com/sul-dlss/preservation_catalog/blob/master/app/models/complete_moab.rb#L1-L10)

## Seed the catalog (with data about the Moabs on the storage roots the catalog tracks -- presumes rake db:seed already performed)

_<sub>Note: "seed" might be slightly confusing terminology here, see https://github.com/sul-dlss/preservation_catalog/issues/1154</sub>_

Seeding the catalog presumes an empty or nearly empty database -- otherwise seeding will throw `druid NOT expected to exist in catalog but was found` errors for each found object.
Seeding does more validation than regular M2C.

From console:
```ruby
Audit::MoabToCatalog.seed_catalog_for_all_storage_roots
```

#### Reset the catalog for re-seeding

WARNING! this will erase the catalog, and thus require re-seeding from scratch.  It is mostly intended for development purposes, and it is unlikely that you'll need to run this against production once the catalog is in regular use.

* Deploy the branch of the code with which you wish to seed, to the instance which you wish to seed (e.g. master to stage).
* Reset the database for that instance.  E.g., on production or stage:  `RAILS_ENV=production bundle exec rake db:reset`
  * note that if you do this while `RAILS_ENV=production` (i.e. production or stage), you'll get a scary warning along the lines of:
  ```
  ActiveRecord::ProtectedEnvironmentError: You are attempting to run a destructive action against your 'production' database.
  If you are sure you want to continue, run the same command with the environment variable:
  DISABLE_DATABASE_ENVIRONMENT_CHECK=1
  ```
  Basically an especially inconvenient confirmation dialogue.  For safety's sake, the full command that skips that warning can be constructed by the user as needed, so as to prevent unintentional copy/paste dismissal when the user might be administering multiple deployment environments simultaneously.  Inadvertent database wipes are no fun.
  * `db:reset` will make sure db is migrated and seeded.  If you want to be extra sure: `RAILS_ENV=[environment] bundle exec rake db:migrate db:seed`

### run `rake db:seed` on remote servers:
These require the same credentials and setup as a regular Capistrano deploy.

```sh
bundle exec cap stage db_seed # for the stage servers
```

or

```sh
bundle exec cap prod db_seed # for the prod servers
```

### Populate the catalog

In console, start by finding the storage root.

```ruby
msr = MoabStorageRoot.find_by!(name: name)
Audit::MoabToCatalog.seed_catalog_for_dir(msr.storage_location)
```

Or for all roots:
```ruby
MoabStorageRoot.find_each { |msr| Audit::MoabToCatalog.seed_catalog_for_dir(msr.storage_location) }
```

## Development

### Seed

You should only need to do this:
* when you first start developing on Preservation Catalog
* after nuking your test database
* when adding storage roots or zip endpoints:
```
RAILS_ENV=test bundle exec rails db:reset
```

The above populates the database with PreservationPolicy, MoabStorageRoot, and ZipEndpoint objects
as defined in the configuration files.

If you are new to developing on this project, you should read [the database README](db/README.md).  It
has a detailed explanation of the data model, some sample queries, and an ER diagram illustrating the
DB table relationships.  For those less familiar with ActiveRecord, there is also some guidance about
how this project uses it.

_Please keep the database README up to date as the schema changes!_

You may also wish to glance at the (much shorter) [Replication README](app/jobs/README.md).

### Running Tests

To run the tests:

```sh
bundle exec rspec
```

### Docker

A Dockerfile is provided in order to interact with the application in development.

Build the docker image:

```sh
docker-compose build app
```

Bring up the docker container and its dependencies:

```sh
docker-compose up -d
```

Initialize the database:

```sh
docker-compose run app bundle exec rails db:reset db:seed
```

Interact with the application via localhost:
```sh
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' -F 'druid=druid:bj102hs9688' -F 'incoming_version=3' -F 'incoming_size=2070039' -F 'storage_location=spec/fixtures/storage_root01' -F 'checksums_validated=true' http://localhost:3000/v1/catalog
```

```sh
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' http://localhost:3000/v1/objects/druid:bj102hs9688

{
  "id":1,
  "druid":"bj102hs9688",
  "current_version":3,
  "created_at":"2019-12-20T15:04:56.854Z",
  "updated_at":"2019-12-20T15:04:56.854Z",
  "preservation_policy_id":1
}
```

## Deploying

Capistrano is used to deploy.  You will need SSH access to the targeted servers, via `kinit` and VPN.

```sh
bundle exec cap stage deploy # for the stage servers
```

Or:

```sh
bundle exec cap prod deploy # for the prod servers
```

### Resque Pool
The Resque Pool admin interface is available at `<hostname>/resque/overview`.

## API

Note that the API is now versioned. Until all clients have been modified to use the V1 routes, requests to URIs without explicit versions -- *i.e.*, hitting /catalog instead of /v1/catalog -- will automatically be redirected to their V1 equivalents. After that point, only requests to explicitly versioned endpoints will be serviced.

### AuthN

Authentication/authorization is handled by JWT.  Preservation Catalog mints JWTs for individual client services, and the client services each provide their respective JWT when making HTTP API calls to PresCat.

To generate an authentication token run `rake generate_token` on the server to which the client will connect (e.g. stage, prod).  This will use the HMAC secret to sign the token. It will ask you to submit a value for "Account". This should be the name of the calling service, or a username if this is to be used by a specific individual. This value is used for traceability of errors and can be seen in the "Context" section of a Honeybadger error. For example:

```ruby
{"invoked_by" => "preservation-robots"}
```

The token generated by `rake generate_token` should be passed along in the `Authorization` header as `Bearer <GENERATED_TOKEN_VALUE>`.

API requests that do not supply a valid token for the target server will be rejected as Unauthorized.

At present, all tokens grant the same (full) access to the read/update API.

### V1

##### NOTE: The first token in the first `curl` example below is a full valid token generated from the public (bad, low entropy) example HMAC secret.  For readability, all other token values are abbreviated (and so those example tokens will be invalid).

#### `GET /v1/objects/:druid`
Return the PreservedObject model for the object.

```
curl -H 'Authorization: Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJwcmVzLXRlc3RfMjAyMC0wMS0xMyJ9.lWMJ66Wjfl2lY5MdikDpjjhpyD_uBX4DMZC5mlgq2T2-bSmrYcbcxfyNfQKXWrUzBc1xOuwYZWxkYL6EejzHvQ' https://preservation-catalog-prod-01.stanford.edu/v1/objects/druid:bb000kg4251
{
  "id": 1786188,
  "druid": "bb000kg4251",
  "current_version": 1,
  "created_at": "2019-06-26T18:38:03.077Z",
  "updated_at": "2019-06-26T18:38:03.077Z",
  "preservation_policy_id": 1
}
```

#### `GET /v1/objects/:druid/file?category=:category&filepath=:filepath&version=:version`
Returns a content, metadata, or manifest file for the object.

Parameters:
* category (values: content|manifest|metadata): category of file
* filepath: path of file, relative to category directory
* version (optional, default: latest): version of Moab

```
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' "https://preservation-catalog-prod-01.stanford.edu/v1/objects/druid:bb000kg4251/file?category=manifest&filepath=signatureCatalog.xml&version=1"
<?xml version="1.0" encoding="UTF-8"?>
<signatureCatalog objectId="druid:bb000kg4251" versionId="1" catalogDatetime="2019-06-26T18:38:02Z" fileCount="10" byteCount="1364250" blockCount="1337">
  <entry originalVersion="1" groupId="content" storagePath="bb000kg4251.jpg">
    <fileSignature size="1347965" md5="abf0fd6d318bab3a5daf1b3e545ca8ac" sha1="eb68cd8ece6be6570e14358ecae66f3ac3026d21" sha256="4d38d804d050bf3bdc41150869f2d09f156043cc1ec215fd65dafbeb8243187f"/>
  </entry>
  ...
</signatureCatalog>
```

#### `GET /v1/objects/:druid/checksum`
Return the checksums and filesize for a single object.

```
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' https://preservation-catalog-prod-01.stanford.edu/v1/objects/druid:bb000kg4251/checksum
[
  {
    "filename": "bb000kg4251.jpg",
    "md5": "abf0fd6d318bab3a5daf1b3e545ca8ac",
    "sha1": "eb68cd8ece6be6570e14358ecae66f3ac3026d21",
    "sha256": "4d38d804d050bf3bdc41150869f2d09f156043cc1ec215fd65dafbeb8243187f",
    "filesize": 1347965
  }
]
```

#### `GET|POST /v1/objects/checksums?druids[]=:druid`
Return the checksums and filesize for multiple objects.

Parameters:
* druid[] (repeatable): druid for the object

```
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' "https://preservation-catalog-prod-01.stanford.edu/v1/objects/checksums?druids[]=druid:bb000kg4251&druids[]=druid:bb000kq3835"
[
  {
    "druid:bb000kg4251": [
      {
        "filename": "bb000kg4251.jpg",
        "md5": "abf0fd6d318bab3a5daf1b3e545ca8ac",
        "sha1": "eb68cd8ece6be6570e14358ecae66f3ac3026d21",
        "sha256": "4d38d804d050bf3bdc41150869f2d09f156043cc1ec215fd65dafbeb8243187f",
        "filesize": 1347965
      }
    ]
  },
  {
    "druid:bb000kq3835": [
      {
        "filename": "2011-023MAIL-1951-b4_22.1_0014.tif",
        "md5": "6c3501fd2a9449f280a483254d4ab84e",
        "sha1": "f15119aed799103f00a08aea6daafaf72e0b7fe4",
        "sha256": "89e211f48f1fb84ceeaee3405daa0755e131d122173c9ed2a8bfc5eee18d77ad",
        "filesize": 11127448
      }
    ]
  }
]
```

#### `POST /v1/objects/:druid/content_diff`
Retrieves FileInventoryDifference model from comparison of passed contentMetadata.xml with latest (or specified) version in Moab for all files (default) or a specified subset.

Parameters:
* content_metadata: contentMetadata.xml to compare.
* subset (optional; default: all; values: all|shelve|preserve|publish): subset of files to compare.
* version (optional, default: latest): version of Moab

```
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' -F 'content_metadata=
<?xml version="1.0"?>
<contentMetadata objectId="bb000kg4251" type="image">
  <resource id="bb000kg4251_1" sequence="1" type="image">
    <label>Image 1</label>
    <file id="bb000kg4251.jpg" mimetype="image/jpeg" size="1347965" preserve="yes" publish="no" shelve="no">
      <checksum type="md5">abf0fd6d318bab3a5daf1b3e545ca8ac</checksum>
      <checksum type="sha1">eb68cd8ece6be6570e14358ecae66f3ac3026d21</checksum>
      <imageData width="3184" height="2205"/>
    </file>
    <file id="bb000kg4251.jp2" mimetype="image/jp2" size="1333879" preserve="no" publish="yes" shelve="yes">
      <checksum type="md5">7f682a6acaecb00ec23dc5b15e61ee87</checksum>
      <checksum type="sha1">8356f16250042158e8d91ef4f86646a7d58aae0b</checksum>
      <imageData width="3184" height="2205"/>
    </file>
  </resource>
</contentMetadata>' https://preservation-catalog-prod-01.stanford.edu/v1/objects/druid:bb000kg4251/content_diff

<?xml version="1.0"?>
<fileInventoryDifference objectId="bb000kg4251" differenceCount="0" basis="v1-contentMetadata-all" other="new-contentMetadata-all" reportDatetime="2019-12-12T20:20:30Z">
  <fileGroupDifference groupId="content" differenceCount="0" identical="2" copyadded="0" copydeleted="0" renamed="0" modified="0" added="0" deleted="0">
    <subset change="identical" count="2">
      <file change="identical" basisPath="bb000kg4251.jpg" otherPath="same">
        <fileSignature size="1347965" md5="abf0fd6d318bab3a5daf1b3e545ca8ac" sha1="eb68cd8ece6be6570e14358ecae66f3ac3026d21" sha256=""/>
      </file>
      <file change="identical" basisPath="bb000kg4251.jp2" otherPath="same">
        <fileSignature size="1333879" md5="7f682a6acaecb00ec23dc5b15e61ee87" sha1="8356f16250042158e8d91ef4f86646a7d58aae0b" sha256=""/>
      </file>
    </subset>
    <subset change="copyadded" count="0"/>
    <subset change="copydeleted" count="0"/>
    <subset change="renamed" count="0"/>
    <subset change="modified" count="0"/>
    <subset change="added" count="0"/>
    <subset change="deleted" count="0"/>
  </fileGroupDifference>
</fileInventoryDifference>
```

#### `POST /v1/catalog`
Add an existing moab object to the catalog.

Parameters:
* druid: druid of the object to add.
* incoming_version: version of the object to add.
* incoming_size: size in bytes of the object on disk.
* storage_location: Storage root where the moab object is located.
* checksums_validated: whether the checksums for the moab object have previously been validated by caller.

Response codes:
* 201: new object created.
* 409: object already exists.
* 406: error with provided parameters or missing parameters.
* 500: some other problem.

```
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' -F 'druid=druid:bj102hs9688' -F 'incoming_version=3' -F 'incoming_size=2070039' -F 'storage_location=spec/fixtures/storage_root01' -F 'checksums_validated=true' https://preservation-catalog-stage-01.stanford.edu/v1/catalog

{
	"druid": "bj102hs9688",
	"result_array": [{
		"created_new_object": "added object to db as it did not exist"
	}]
}
```

#### `PUT/PATCH /v1/catalog/:druid`
Updating an existing record for a moab object in the catalog for a new version.

Parameters:
* incoming_version: version of the object to add.
* incoming_size: size in bytes of the object on disk.
* storage_location: Storage root where the moab object is located.
* checksums_validated: whether the checksums for the moab object have previously been validated by caller.

Response codes:
* 200: update successful.
* 400: version is less than the current recorded version for the moab object.
* 404: object not found.
* 406: error with provided parameters or missing parameters.
* 500: some other problem.

```
curl -H 'Authorization: Bearer eyJhbGcxxxxx.eyJzdWIxxxxx.lWMJ66Wxx-xx' -X PUT -F 'incoming_version=4' -F 'incoming_size=2136079' -F 'storage_location=spec/fixtures/storage_root01' -F 'checksums_validated=true' https://preservation-catalog-stage-01.stanford.edu/v1/catalog/druid:bj102hs9688

{
	"druid": "bj102hs9688",
	"result_array": [{
		"actual_vers_gt_db_obj": "actual version (4) greater than CompleteMoab db version (3)"
	}]
}
```
