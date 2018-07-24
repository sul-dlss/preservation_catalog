### schema explanation (as of 2017-12-14)

##### Schema Entity-Relationship Diagram
![Schema Entity-Relationship Diagram as of 2017-12-14](schema_ER_diagram.2017-12-14.png)

###### Key:
* <sub>The diagram is generated from a Postgres schema dump, so the tables are listed by their SQL names.  Each SQL table has a corresponding ActiveRecord class, whose name is a camel case version of the snake case SQL name (with one exception, explained below).  The explanation tries to use the SQL table name or the ActiveRecord classname according to which is most appropriate, and may be arbitrary when either would suffice.</sub>
* <sub>`FK` in the diagram indicates a [foreign key](https://en.wikipedia.org/wiki/Foreign_key) constraint on that column to a row in another table.</sub>
* <sub>`PK` in the diagram indicates the [primary key](https://en.wikipedia.org/wiki/Unique_key#Defining_primary_keys_in_SQL) column for the table.</sub>
* <sub>The cross side of the connection between tables indictates a required foreign key relationship, or what ActiveRecord would call `belongs_to` (with a `null: false` constraint on the column definition and a corresponding `presence: true` on the ActiveRecord class definition).  In our current data model, none of our foreign key reference fields may be null.  Each such ActiveRecord object must point to exactly one instance of its foreign key referent.</sub>
  * <sub>E.g., a row in `preserved_copies` (retrievable as a `PreservedCopy` ActiveRecord object) must point to (`belong_to`) exactly one row in `preserved_objects` (a `PreservedObject`).</sub>
* <sub>The fork side of the connection between tables indicates a one to 0 or more relationship, or what ActiveRecord calls `has_many`.</sub>
  * <sub>E.g., a row in `endpoint_types` (an `EndpointType`) may have many corresponding rows in `endpoints` (retrievable as `Endpoint` objects).  And while it's possible for an `EndpointType` to have no associated `Endpoint` objects, this would be a fishy situation: one might define an endpoint type ahead of the corresponding endpoints that implement it, but in general, we should probably not have `PreservedObject`s, `EndpointType`s, or `PreservationPolicy`s that aren't actually used by anything else.</sub>
* <sub>We have one thin "join table", `endpoint_preservation_policies`, which has no corresponding ActiveRecord class.  ActiveRecord is made aware of the mapping between the `endpoints` and `preservation_policies` tables by way of `has_and_belongs_to_many` relationship declarations on `Endpoint` (to `preservation_policies`) and `PreservationPolicy` (to `endpoints`).</sub>
  * <sub>Semantically, the idea is that an endpoint may be used by more than one preservation policy, and a preservation policy may be implemented by multiple endpoints.  Typically, this sort of many-to-many relationship is expressed in a relational database schema by way of an intermediary table that maps related rows in the two tables.  This is more structured and easier to query/update than, e.g., a list field on a row in one table enumerating all the related row IDs in the other table.</sub>

#### What do these table rows (ActiveRecord objects) represent in the "real" world?  (a list of the ActiveRecord subclasses, and a (non-exhaustive) list of their fields)
* A `PreservedObject` represents the master record for a moab object that we intend to preserve, tying together all of the physically instantiated copies (whether "online" or "archive").  It also holds some high level summary info that applies to all of the related preserved copies.
  * `current_version` is current latest version we've seen for the druid across all instances.
  * `preservation_policy_id` points to the policy governing how the object should be preserved.
* A `PreservedCopy` represents a physical copy of a `PreservedObject`, e.g. an "online" moab stored on premesis and accessed via NFS mount, an "archive" copy sitting on a cloud endpoint (manipulable via REST calls to a 3rd party cloud service), etc.
  * `size`: is approximate, and given in bytes.  It's intended to be used for things like allocating storage.  It should _not_ be treated as an exact value for fixity checking.
  * `status`: a high-level summary of the copy's current state.  This is just a reflection of what we last saw on disk, and does not capture history, nor does it necessarily enumerate all errors for a copy that needs remediation.
* An `Endpoint` represents a physical storage location on which a `PreservedCopy` resides.  E.g., a single NFS-mounted storage root for "online" moabs, or a single bucket from a cloud service holding "archive" copies (such as an Amazon AWS or Oracle Cloud bucket).  The `Endpoint` fields include info about:
  * `endpoint_type_id`: the `EndpointType` implemented by this `Endpoint`.
  * `endpoint_node`: the network location of the endpoint relative to the preservation catalog instance (e.g. localhost for a locally mounted NFS volume, s3.us-east-2.amazonaws.com for an S3 bucket, etc).
  * `storage_location`: the path or bucket name or similar from which to read (e.g. "/services-disk03/sdr2objects", "sdr-bucket-01", etc).
  * `preservation_policies`: the preservation policies for which governed objects are preserved (declared to ActiveRecord via `has_and_belongs_to_many :preservation_policies`).
* An `EndpointType`, as the name implies, describes general shared characteristics common to many `Endpoint` instances.  At present these include a general type name describing what sort of storage the endpoint is to be implemented on (e.g. our own NFS mounts, an AWS bucket, a Ceph instance, etc), as well as the type of objects the endpoint stores (at present, only "online" exploded moabs, or "archive" moabs packed into a single file).
* A `PreservationPolicy` defines
  * `endpoints`: the endpoints to which the objects governed by the policy should preserved (declared to ActiveRecord via `has_and_belongs_to_many :endpoints`).
  * `archive_ttl`: the frequency with which the existence of the appropriate archive copies should be checked.
  * `fixity_ttl`: the frequency with which the online copies should be checked for fixity.


#### other terminology
* An "online" copy is an exploded moab folder structure, on which we can run structural verification or checksum verification for constituent files, and from which we can retrieve individual assets of the moab.
* An "archive" copy is a single file containing a moab's file and folder structure.  Format is still TBD, possibly a plain tar file of a moab object, possibly Bagit bag, possibly ??
* "TTL" is an acronym for "time-to-live", or an expiry age.  In the case of our `archive_ttl` and `fixity_ttl` values, it's the age beyond which we consider the last archive or fixity check result to be stale (in which case those checks should be re-run at the next scheduled opportunity).



### how to use transactions appropriately

The Rails API docs: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html

General advice:
* Please use `ApplicationRecord.transaction` for clarity and consistency.
  * Functionally, it doesn't matter whether `.transaction` is called on a specific ActiveRecord class or object instance, because the transaction applies to the database connection, and all updates in a given thread of operation will be going over the same database connection (it is possible to configure ActiveRecord to do otherwise, but like most applications, we don't).  To reduce confusion, it seems best to just always invoke it via the super-class, so that it's clear that the transaction applies to all object types being grouped under it.
* If two or more things should fail or succeed together atomically, they should be wrapped in a transaction.  E.g. if you're creating a PreservedObject so that there's a master record for the PreservedCopy that you'd like to create, those two things should probably be grouped as a transaction so that if the creation of the PreservedCopy fails, the creation of the PreservedObject gets rolled back, and we don't have a stray lying around.
* Don't wrap more things than needed in a transaction.  If multiple operations can succeed or fail independently, it's both semantically incorrect and needlessly inefficient to group them in a transaction.
  * Likewise, try not to do too much extra processing in the `Application.transaction` block.  It's fine to wrap nested chains of method calls in a transaction, as it might be a pain to decompose your code such that the transaction block literally only contained ActiveRecord operations.  At the same time, the longer a transaction is open, the higher the chances that two different updates will try to update the same thing, possibly causing one of the updates to fail.  So, if it's easy to keep something unnecessary out of the transaction block, it'd be wise to do so.
* In the unlikely event that you're tempted to pro-actively do row-locking, e.g. due to concern about multiple processes updating a shared resource (e.g. if multiple processes were crawling the same storage root and doing moab validation), the Postgres docs seems to advise against that.  Instead, specifying transaction isolation level seems to be recommended as the more robust and performant approach.
  * Isolation level can be passed as a param to the transaction block, e.g. `ApplicationRecord.transaction(isolation: :serializable) { ... }`
  * `serializable` is the strictest isolation level: https://www.postgresql.org/docs/current/static/transaction-iso.html
    * relevant Rails API doc: http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-transaction
    * more background and advice from the PG wiki: https://wiki.postgresql.org/wiki/Serializable
  * If there is actually little contention in practice, the PG docs seem to indicate that specifying isolation level, even something as strict as `serializable`, should have little to no overhead (though it could increase chances of failed updates if there is actual resource contention, though code should already be prepared to handle failed DB updates gracefully).  As such, there seems to be little risk to erring on the side of a strong isolation level when in doubt.
  * *probably shouldn't* do it this way: http://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html
* You should likely be catching ActiveRecord exceptions outside of the transaction block, as you likely want to abort the transaction after the first ActiveRecord exception anyway.  In other words, wrap transactions in exception handling, and not vice versa.  See "Exception handling and rolling back": http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html
* Use for ActiveRecord enums (http://edgeapi.rubyonrails.org/classes/ActiveRecord/Enum.html):
  * Instead of using plain string values everywhere, define class constants for the string values, and use those class constants both when defining the enum, and when referring to enum values in other parts of the codebase.
  * In the enum definition, explicitly map each enum string to its underlying integer value, and leave a note admonishing future developers not to change enums that are already in use in production (or to think about the needed migration).  This is to prevent unintentional re-mapping of existing enum values.
  * Example:  https://github.com/sul-dlss/preservation_catalog/blob/master/app/models/preserved_copy.rb



### some useful ActiveRecord queries
* useful for running from console for now, similar to the sorts of info that might be exposed via REST calls as development proceeds
* things below related to status will change once status becomes a Rails enum on PreservedCopy (see #228)

#### which objects aren't in a good state?
```ruby
# example AR query
[25] pry(main)> PreservedCopy.joins(:preserved_object, :endpoint).where.not(status: :ok).order('preserved_copies.status asc, endpoints.storage_location asc').pluck(:status, :storage_location, :druid)
```
```sql
-- example sql produced by above AR query
SELECT "preserved_copies"."status", "storage_location", "druid"
FROM "preserved_copies"
INNER JOIN "preserved_objects" ON "preserved_objects"."id" = "preserved_copies"."preserved_object_id"
INNER JOIN "endpoints" ON "endpoints"."id" = "preserved_copies"."endpoint_id"
WHERE ("preserved_copies"."status" != $1)
ORDER BY preserved_copies.status asc, endpoints.storage_location asc
```
```ruby
# example result, one bad object on disk 2
[["invalid_moab", "/storage_root2/storage_trunk", "ab123cd456"]]
```

#### catalog seeding just ran for the first time.  how long did it take to crawl each storage root, how many moabs does each have, what's the average moab size?
```ruby
# example AR query
[2] pry(main)> Endpoint.joins(:preserved_copies).group(:endpoint_name).order('endpoint_name asc').pluck(:endpoint_name, 'min(preserved_copies.created_at)', 'max(preserved_copies.created_at)', '(max(preserved_copies.created_at)-min(preserved_copies.created_at))', 'count(preserved_copies.id)', 'round(avg(preserved_copies.size))')
```
```sql
-- example sql produced by above AR query
SELECT "endpoints"."endpoint_name", min(preserved_copies.created_at), max(preserved_copies.created_at), (max(preserved_copies.created_at)-min(preserved_copies.created_at)), count(preserved_copies.id), round(avg(preserved_copies.size))
FROM "endpoints"
INNER JOIN "preserved_copies" ON "preserved_copies"."endpoint_id" = "endpoints"."id"
GROUP BY "endpoints"."endpoint_name"
ORDER BY endpoint_name asc
```
```ruby
# example result when there's one storage root configured, would automatically list all if there were multiple
[["storage_root2", 2017-11-18 05:49:54 UTC, 2017-11-18 06:06:50 UTC, "00:16:55.845987", 9122, 0.3132092573e10]]
```

#### how many moabs on each storage root are have `status != 'ok'`?
```ruby
# example AR query
[12] pry(main)> PreservedCopy.joins(:preserved_object, :endpoint).where.not(status: 'ok').group(:status, :storage_location).order('preserved_copies.status asc, endpoints.storage_location asc').pluck('preserved_copies.status, endpoints.storage_location, count(preserved_objects.druid)')
```
```sql
-- example sql produced by above AR query
SELECT preserved_copies.status, endpoints.storage_location, count(preserved_objects.druid)
FROM "preserved_copies"
INNER JOIN "preserved_objects" ON "preserved_objects"."id" = "preserved_copies"."preserved_object_id"
INNER JOIN "endpoints" ON "endpoints"."id" = "preserved_copies"."endpoint_id"
WHERE ("preserved_copies"."status" != $1)
GROUP BY "preserved_copies"."status", "storage_location"
ORDER BY preserved_copies.status asc, endpoints.storage_location asc
```
```ruby
# example result, some moabs that failed structural validation
[["invalid_moab", "/storage_root02/storage_trunk", 1],
 ["invalid_moab", "/storage_root03/storage_trunk", 412],
 ["invalid_moab", "/storage_root04/storage_trunk", 127],
 ["invalid_moab", "/storage_root05/storage_trunk", 72]]
```

#### view the druids on a given endpoint
- will return tons of results on prod
```ruby
input> PreservedCopy.joins(:preserved_object, :endpoint).where(endpoints: {endpoint_name: :fixture_sr2}).pluck('preserved_objects.druid')
```
```sql
-- example sql produced by above AR query
 SELECT preserved_objects.druid
 FROM "preserved_copies"
 INNER JOIN "preserved_objects" ON "preserved_objects"."id" = "preserved_copies"."preserved_object_id"
 INNER JOIN "endpoints" ON "endpoints"."id" = "preserved_copies"."endpoint_id"
 WHERE "endpoints"."endpoint_name" = $1  [["endpoint_name", "fixture_sr2"]]
```
```ruby
# example result
["bp628nk4868", "dc048cw1328", "yy000yy0000"]
```
