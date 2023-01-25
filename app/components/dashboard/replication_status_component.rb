# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationStatusComponent
  class ReplicationStatusComponent < ViewComponent::Base
    include Dashboard::ReplicationService

    def replication_zips_badge_class
      return OK_BADGE_CLASS if replication_and_zip_parts_ok?

      NOT_OK_BADGE_CLASS
    end

    def replication_zips_status_label
      return OK_LABEL if replication_and_zip_parts_ok?

      NOT_OK_LABEL
    end

    def zip_parts_badge_class
      return OK_BADGE_CLASS if zip_parts_ok?

      NOT_OK_BADGE_CLASS
    end

    def zip_parts_status_label
      return OK_LABEL if zip_parts_ok?

      NOT_OK_LABEL
    end
  end
end
