# Why was this change made? 🤔




# How was this change tested? 🤨

⚠ If this change has cross service impact, or if it changes code used internally for cloud replication, **_run [integration test preassembly_reaccessioning_spec.rb](https://github.com/sul-dlss/infrastructure-integration-test/blob/main/spec/features/preassembly_reaccessioning_spec.rb) against stage, as it tests preservation (including cloud replication)_**, and/or test manually in stage environment, in addition to specs.

The main classes relevant to replication are `ZipmakerJob`, `DeliveryDispatcherJob`, `*DeliveryJob`, `ResultsRecorderJob`, and `DruidVersionZip`; [see here for overview diagram of replication pipeline](https://github.com/sul-dlss/preservation_catalog/wiki/Replication-Flow).

⚠ Run any integration tests that exercise other services impacted by the change, if any.

⚠ If the changes impact JS, Bootstrap, Rails, or any other UI related plumbing: deploy to stage or qa, visit the `/dashboard` URL, and confirm that the dashboard still functions correctly. Some sections may take a minute to load, as they are running somewhat expensive queries.


# Does your change introduce accessibility violations? 🩺

⚠ Please ensure this change does not introduce accessibility violations (at the WCAG A or AA conformance levels); if it does, include a rationale. See the [Infrastructure accessibility guide](https://github.com/sul-dlss/DeveloperPlaybook/blob/main/best-practices/infra-accessibility.md) for more detail.



