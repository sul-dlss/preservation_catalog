# Why was this change made?




# How was this change tested?

⚠ If this change has cross service impact or if it changes code used internally for cloud replication, running [integration test preassembly_reaccessioning_spec.rb](https://github.com/sul-dlss/infrastructure-integration-test/blob/main/spec/features/preassembly/preassembly_reaccessioning_spec.rb) is recommended (because it will make an object with more than one version and check to see that it made it all the way through preservation, including cloud replication).
