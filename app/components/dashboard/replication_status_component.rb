# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationStatusComponent
  class ReplicationStatusComponent < ViewComponent::Base
    include Dashboard::ReplicationService

    def replication_zips_badge_class
      return OK_BADGE_CLASS if replication_and_zipped_moab_versions_ok?

      NOT_OK_BADGE_CLASS
    end

    def replication_zips_status_label
      return OK_LABEL if replication_and_zipped_moab_versions_ok?

      NOT_OK_LABEL
    end

    def zipped_moab_versions_badge_class
      return OK_BADGE_CLASS unless zipped_moab_versions_failed?

      NOT_OK_BADGE_CLASS
    end

    def zipped_moab_versions_status_label
      return OK_LABEL unless zipped_moab_versions_failed?

      NOT_OK_LABEL
    end
  end
end
