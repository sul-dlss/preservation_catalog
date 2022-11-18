## Why was this change made? 🤔



## How was this change tested? 🤨

⚡ ⚠ If this change has cross service impact, or if it changes code used internally for cloud replication, ***run [integration test preassembly_image_accessioning_spec.rb](https://github.com/sul-dlss/infrastructure-integration-test/blob/main/spec/features/preassembly_image_accessioning_spec.rb) against stage as it tests preservation***, and/or test in stage environment, in addition to specs. The main classes relevant to replication are `ZipmakerJob`, `PlexerJob`, `*DeliveryJob`, `ResultsRecorderJob`, and `DruidVersionZip`; [see here for overview diagram of replication pipeline](https://github.com/sul-dlss/preservation_catalog/blob/main/app/jobs/README.md).⚡



