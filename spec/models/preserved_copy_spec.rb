require 'rails_helper'

RSpec.describe PreservedCopy, type: :model do
  let(:endpoint) { Endpoint.find_by(endpoint_name: 'fixture_sr1') }
  let!(:preserved_object) do
    policy_id = PreservationPolicy.default_policy.id
    PreservedObject.create!(druid: 'ab123cd4567', current_version: 1, preservation_policy_id: policy_id)
  end
  let!(:status) { described_class::VALIDITY_UNKNOWN_STATUS }
  let!(:preserved_copy) do
    PreservedCopy.create!(
      preserved_object_id: preserved_object.id,
      endpoint_id: endpoint.id,
      version: 0,
      status: status,
      size: 1
    )
  end

  it 'is not valid without valid attributes' do
    expect(PreservedCopy.new).not_to be_valid
  end

  it 'is not valid unless it has all required attributes' do
    expect(PreservedCopy.new(preserved_object_id: preserved_object.id)).not_to be_valid
  end

  it 'is valid with valid attributes' do
    expect(preserved_copy).to be_valid
  end

  it 'defines a status enum with the expected values' do
    is_expected.to define_enum_for(:status).with(
      PreservedCopy::OK_STATUS => 0,
      PreservedCopy::INVALID_MOAB_STATUS => 1,
      PreservedCopy::INVALID_CHECKSUM_STATUS => 2,
      PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS => 3,
      PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS => 4,
      PreservedCopy::VALIDITY_UNKNOWN_STATUS => 6
    )
  end

  context '#status=' do
    it "validation rejects an int value that's not actually used by the enum" do
      expect {
        PreservedCopy.new(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint.id,
          version: 0,
          status: 654,
          size: 1
        )
      }.to raise_error(ArgumentError, "'654' is not a valid status")
    end

    it "validation rejects a value if it isn't one of the defined enum identifiers" do
      expect {
        PreservedCopy.new(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint.id,
          version: 0,
          status: 'INVALID_MOAB',
          size: 1
        )
      }.to raise_error(ArgumentError, "'INVALID_MOAB' is not a valid status")
    end

    it "will accept a symbol, but will always return a string" do
      pc = PreservedCopy.new(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: :invalid_moab,
        size: 1
      )
      expect(pc.status).to be_a(String)
      expect(pc.status).to eq PreservedCopy::INVALID_MOAB_STATUS
    end
  end

  it { is_expected.to belong_to(:endpoint) }
  it { is_expected.to belong_to(:preserved_object) }
  it { is_expected.to have_db_index(:last_version_audit) }
  it { is_expected.to have_db_index(:last_moab_validation) }
  it { is_expected.to have_db_index(:last_checksum_validation) }
  it { is_expected.to have_db_index(:endpoint_id) }
  it { is_expected.to have_db_index(:preserved_object_id) }

  describe '#update_audit_timestamps' do
    let(:pc) do
      PreservedCopy.new(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: PreservedCopy::INVALID_MOAB_STATUS,
        size: 1
      )
    end

    it 'updates last_moab_validation time if moab_validated is true' do
      expect(pc.last_moab_validation).to be nil
      pc.update_audit_timestamps(true, false)
      expect(pc.last_moab_validation).not_to be nil
    end
    it 'does not update last_moab_validation time if moab_validated is false' do
      expect(pc.last_moab_validation).to be nil
      pc.update_audit_timestamps(false, false)
      expect(pc.last_moab_validation).to be nil
    end
    it 'updates last_version_audit time if version_audited is true' do
      expect(pc.last_version_audit).to be nil
      pc.update_audit_timestamps(false, true)
      expect(pc.last_version_audit).not_to be nil
    end
    it 'does not update last_version_audit time if version_audited is false' do
      expect(pc.last_version_audit).to be nil
      pc.update_audit_timestamps(false, false)
      expect(pc.last_version_audit).to be nil
    end
  end

  describe '#upd_audstamps_version_size' do
    let(:pc) do
      PreservedCopy.new(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: PreservedCopy::INVALID_MOAB_STATUS,
        size: 1
      )
    end

    it 'updates version' do
      pc.upd_audstamps_version_size(false, 3, nil)
      expect(pc.version).to eq 3
    end

    it 'updates size if size is not nil' do
      pc.upd_audstamps_version_size(false, 0, 123)
      expect(pc.size).to eq 123
    end

    it 'does not update size if size is nil' do
      pc.upd_audstamps_version_size(false, 0, nil)
      expect(pc.size).to eq 1
    end

    it 'calls update_audit_timestamps with the appropriate params' do
      expect(pc).to receive(:update_audit_timestamps).with(false, true)
      pc.upd_audstamps_version_size(false, 3, nil)
    end
  end

  describe '#update_status' do
    let(:pc) do
      # using create here, because if the object has never been saved, #changed? will always return true
      PreservedCopy.create(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: PreservedCopy::INVALID_MOAB_STATUS,
        size: 1
      )
    end

    it 'does nothing if the status has not changed' do
      ran_the_block = false
      pc.update_status(PreservedCopy::INVALID_MOAB_STATUS) { ran_the_block = true }
      expect(pc.status).to eq PreservedCopy::INVALID_MOAB_STATUS
      expect(ran_the_block).to eq false
      expect(pc.changed?).to eq false
    end

    it 'runs the block and updates the status if the status has changed' do
      ran_the_block = false
      pc.update_status(PreservedCopy::OK_STATUS) { ran_the_block = true }
      expect(pc.status).to eq PreservedCopy::OK_STATUS
      expect(ran_the_block).to eq true
      expect(pc.changed?).to eq true
    end
  end

  context '#matches_po_current_version?' do
    it 'returns true when its version matches its preserved objects current version' do
      preserved_copy.version = 666
      preserved_copy.preserved_object.current_version = 666
      expect(preserved_copy.matches_po_current_version?).to be true
    end

    it 'returns false when its version does not match its preserved objects current version' do
      preserved_copy.version = 666
      preserved_copy.preserved_object.current_version = 777
      expect(preserved_copy.matches_po_current_version?).to be false
    end
  end

  context '.least_recent_version_audit(last_checked_b4_date)' do
    let!(:newer_timestamp_pc) do
      PreservedCopy.create!(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 1,
        status: status,
        size: 1,
        last_version_audit: (Time.now.utc - 1.day)
      )
    end
    let!(:older_timestamp_pc) do
      PreservedCopy.create!(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 1,
        status: status,
        size: 1,
        last_version_audit: (Time.now.utc - 2.days)
      )
    end
    let!(:future_timestamp_pc) do
      PreservedCopy.create!(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 1,
        status: status,
        size: 1,
        last_version_audit: (Time.now.utc + 1.day)
      )
    end
    let!(:nil_timestamp_pc) { preserved_copy }
    let!(:pcs_ordered_by_query) { PreservedCopy.least_recent_version_audit(Time.now.utc) }

    it 'returns PreservedCopies with nils first, then old to new timestamps' do
      expect(pcs_ordered_by_query).to eq [nil_timestamp_pc, older_timestamp_pc, newer_timestamp_pc]
    end
    it 'returns no PreservedCopies with future timestamps' do
      expect(pcs_ordered_by_query).not_to include future_timestamp_pc
    end

    context '.normalize_date(timestamp)' do
      it 'given a String timestamp, returns a Time object' do
        expect(described_class.send(:normalize_date, '2018-01-22T18:54:48')).to be_an_instance_of(Time)
      end
      it 'given a Time Object, returns the same Time object' do
        expect(described_class.send(:normalize_date, Time.now.utc)).to be_an_instance_of(Time)
      end
      it 'given nil, returns a TypeError' do
        expect { described_class.send(:normalize_date, nil) }.to raise_error(TypeError, /no implicit conversion/)
      end
      it 'given an unparseable date returns an ArgumentError' do
        expect { described_class.send(:normalize_date, 'an 6') }.to raise_error(ArgumentError, /no time information/)
      end
      it 'given day only returns a Time object with 08:00:00 UTC time' do
        expect(described_class.send(:normalize_date, '2018-02-02')).to be_an_instance_of(Time)
      end
      it 'given a month only returns Time object with 2018-04-01 07:00:00 UTC time' do
        expect(described_class.send(:normalize_date, 'April')).to be_an_instance_of(Time)
      end
      it 'given a year only returns an ArgumentError' do
        expect { described_class.send(:normalize_date, '2014') }.to raise_error(ArgumentError, /argument out of range/)
      end
    end
  end

  context '.fixity_check_expired' do
    let(:fixity_ttl) { preserved_object.preservation_policy.fixity_ttl }
    let(:just_over_fixity_ttl) { fixity_ttl + 1.second }
    let(:just_under_fixity_ttl) { fixity_ttl - 1.second }

    let!(:never_checked_pc) { preserved_copy }
    let!(:checked_before_threshold_pc1) do
      PreservedCopy.create!(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 1,
        status: status,
        size: 1,
        last_checksum_validation: (Time.now.utc - (fixity_ttl * 2))
      )
    end
    let!(:checked_before_threshold_pc2) do
      PreservedCopy.create!(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 1,
        status: status,
        size: 1,
        last_checksum_validation: (Time.now.utc - just_over_fixity_ttl)
      )
    end
    let!(:recently_checked_pc1) do
      PreservedCopy.create!(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 1,
        status: status,
        size: 1,
        last_checksum_validation: (Time.now.utc - just_under_fixity_ttl)
      )
    end
    let!(:recently_checked_pc2) do
      PreservedCopy.create!(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 1,
        status: status,
        size: 1,
        last_checksum_validation: (Time.now.utc - (fixity_ttl * 0.1))
      )
    end
    let!(:pcs_ordered_by_query) { PreservedCopy.fixity_check_expired }

    it 'returns PreservedCopies that need fixity check, never checked first, then least-recently to most-recently' do
      expect(pcs_ordered_by_query).to eq [never_checked_pc, checked_before_threshold_pc1, checked_before_threshold_pc2]
    end
    it 'returns no PreservedCopies with timestamps indicating still-valid fixity check' do
      expect(pcs_ordered_by_query).not_to include recently_checked_pc1
      expect(pcs_ordered_by_query).not_to include recently_checked_pc2
    end
  end

  context '.by_endpoint_name' do
    it 'returns the expected preserved copies' do
      expect(PreservedCopy.by_endpoint_name('fixture_sr1').length).to eq 1
      expect(PreservedCopy.by_endpoint_name('fixture_sr2').length).to eq 0
      expect(PreservedCopy.by_endpoint_name('fixture_empty').length).to eq 0
    end
  end

  context '.by_storage_location' do
    it 'returns the expected preserved copies' do
      expect(PreservedCopy.by_storage_location('spec/fixtures/storage_root01/moab_storage_trunk').length).to eq 1
      expect(PreservedCopy.by_storage_location('spec/fixtures/storage_root02/moab_storage_trunk').length).to eq 0
      expect(PreservedCopy.by_storage_location('spec/fixtures/empty/moab_storage_trunk').length).to eq 0
    end
  end

  context '.by_druid' do
    it 'returns the expected preserved copies' do
      expect(PreservedCopy.by_druid('ab123cd4567').length).to eq 1
      expect(PreservedCopy.by_druid('bj102hs9687').length).to eq 0
    end
  end

  # this is not intended to exhaustively test all permutations, but to highlight/test likely useful combos
  context 'chained scopes' do
    context '.fixity_check_expired' do
      let(:endpoint2) { Endpoint.find_by(endpoint_name: 'fixture_sr2') }
      let!(:never_checked_pc) { preserved_copy }
      let!(:checked_before_threshold_pc1) do
        PreservedCopy.create!(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint.id,
          version: 1,
          status: status,
          size: 1,
          last_checksum_validation: (Time.now.utc - 3.weeks)
        )
      end
      let!(:checked_before_threshold_pc2) do
        PreservedCopy.create!(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint2.id,
          version: 1,
          status: status,
          size: 1,
          last_checksum_validation: (Time.now.utc - 7.01.days)
        )
      end
      let!(:recently_checked_pc1) do
        PreservedCopy.create!(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint.id,
          version: 1,
          status: status,
          size: 1,
          last_checksum_validation: (Time.now.utc - 6.99.days)
        )
      end
      let!(:recently_checked_pc2) do
        PreservedCopy.create!(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint2.id,
          version: 1,
          status: status,
          size: 1,
          last_checksum_validation: (Time.now.utc - 1.day)
        )
      end

      context '.by_endpoint_name' do
        let(:pcs_ordered_by_query1) { PreservedCopy.fixity_check_expired.by_endpoint_name('fixture_sr1') }
        let(:pcs_ordered_by_query2) { PreservedCopy.fixity_check_expired.by_endpoint_name('fixture_sr2') }

        it 'returns PreservedCopies with nils first, then old to new timestamps, only for the chosen storage root' do
          expect(pcs_ordered_by_query1).to eq [never_checked_pc, checked_before_threshold_pc1]
          expect(pcs_ordered_by_query2).to eq [checked_before_threshold_pc2]
        end
        it 'returns no PreservedCopies with timestamps indicating fixity check in the last week' do
          expect(pcs_ordered_by_query1).not_to include recently_checked_pc1
          expect(pcs_ordered_by_query2).not_to include recently_checked_pc2
        end
      end

      context '.by_storage_location' do
        let!(:pcs_ordered_by_query1) do
          PreservedCopy.fixity_check_expired.by_storage_location('spec/fixtures/storage_root01/moab_storage_trunk')
        end
        let!(:pcs_ordered_by_query2) do
          PreservedCopy.fixity_check_expired.by_storage_location('spec/fixtures/storage_root02/moab_storage_trunk')
        end

        it 'returns PreservedCopies with nils first, then old to new timestamps, only for the chosen storage root' do
          expect(pcs_ordered_by_query1).to eq [never_checked_pc, checked_before_threshold_pc1]
          expect(pcs_ordered_by_query2).to eq [checked_before_threshold_pc2]
        end
        it 'returns no PreservedCopies with timestamps indicating fixity check in the last week' do
          expect(pcs_ordered_by_query1).not_to include recently_checked_pc1
          expect(pcs_ordered_by_query2).not_to include recently_checked_pc2
        end
      end
    end
  end
end
