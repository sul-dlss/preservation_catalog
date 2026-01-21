# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreservedObjectCalculations do
  describe '.expired_archive_audit_with_grace_count' do
    before do
      # Default expiration is 90 days. Grace is 7 days.
      create(:preserved_object, last_archive_audit: 10.days.ago)
      create(:preserved_object, last_archive_audit: 91.days.ago)
      create(:preserved_object, last_archive_audit: 100.days.ago)
    end

    it 'returns the count of PreservedObjects with expired archive audits with grace period' do
      expect(PreservedObject.expired_archive_audit_with_grace_count).to eq(1)
    end
  end
end
