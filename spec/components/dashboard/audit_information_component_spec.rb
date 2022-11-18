# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::AuditInformationComponent, type: :component do
  let(:storage_root) { create(:moab_storage_root) }
  let(:rendered) { render_inline(described_class.new) }

  it 'renders Audit Information' do
    expect(rendered).to match(/Audit Information/)
    expect(rendered).to match(/objects with errors/) # table header
    expect(rendered).to match(/0/) # table data
  end

  context 'when at least one CompleteMoab has last_version_audit older than MOAB_LAST_VERSION_AUDIT_THRESHOLD' do
    before do
      create(:complete_moab, last_version_audit: 45.days.ago)
      create(:complete_moab, last_version_audit: 1.day.ago)
      create(:complete_moab, last_version_audit: 2.days.ago)
      create(:complete_moab, last_version_audit: 30.days.ago)
    end

    it 'renders Moab audits older than threshold with warning styling' do
      expect(rendered.css('.table-warning').text).to match(/Moab audits older than/)
      expect(rendered.css('.table-warning').size).to be >= 4
    end
  end

  context 'when no CompleteMoabs have last_version_audit older than MOAB_LAST_VERSION_AUDIT_THRESHOLD' do
    before do
      create(:complete_moab, last_version_audit: 5.days.ago)
    end

    it 'renders Moab audits older than threshold without warning styling' do
      expect(rendered.css('.table-warning').text).not_to match(/Moab audits older than/)
    end
  end

  describe 'when CompleteMoabs have expired checksums' do
    before do
      create(:complete_moab, moab_storage_root: storage_root, last_checksum_validation: Time.zone.now)
      create(:complete_moab, preserved_object: create(:preserved_object), last_checksum_validation: 4.months.ago)
      create(:complete_moab, moab_storage_root: storage_root)
    end

    it 'renders CompleteMoab.fixity_check_expired.count with warning styling' do
      expired_checksums_node = rendered.css('.table-warning').find { |node| node.text =~ /passing checks expire 90 days after they are run\)$/ }
      expect(expired_checksums_node.content).to match(/^2/)
    end
  end

  context 'when at least one PreservedObject has archive_check_expired' do
    before do
      create(:preserved_object, last_archive_audit: 95.days.ago)
      create(:preserved_object) # last_archive_audit is nil so it counts
      create(:preserved_object, last_archive_audit: 132.days.ago)
      create(:preserved_object, last_archive_audit: 5.days.ago)
    end

    it 'renders PreservedObject replication audits older than threshold with warning styling' do
      expect(rendered.css('.table-warning').text).to match(/PreservedObject replication audits older than.*3$/)
    end
  end

  context 'when no PreservedObjects have last_version_audit older than archive_check_expired' do
    before do
      create(:preserved_object, last_archive_audit: 5.days.ago)
      create(:preserved_object, last_archive_audit: 2.days.ago)
    end

    it 'renders PreservedObject replication audits older than threshold without warning styling' do
      expect(rendered).not_to have_css('.table-warning')
    end
  end
end
