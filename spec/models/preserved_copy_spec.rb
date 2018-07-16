require 'rails_helper'

RSpec.describe PreservedCopy, type: :model do
  let(:druid) { 'ab123cd4567' }
  let(:endpoint) { Endpoint.find_by(endpoint_name: 'fixture_sr1') }
  let(:preserved_object) do
    create(
      :preserved_object,
      druid: druid,
      current_version: 1,
      preservation_policy_id: PreservationPolicy.default_policy.id
    )
  end
  let(:status) { 'validity_unknown' }
  let(:pc_version) { 1 }
  let(:args) do # default constructor params
    {
      preserved_object: preserved_object,
      endpoint: endpoint,
      version: pc_version,
      status: status,
      size: 1
    }
  end

  # some tests assume the PC and PO exist before the vars are referenced.  the eager instantiation of pc will cause
  # instantiation of preserved_object, since pc depends on it (via args).
  let!(:pc) { create(:preserved_copy, args) }
  let(:now) { Time.now.utc }

  it 'is not valid without all required valid attributes' do
    expect(described_class.new).not_to be_valid
    expect(described_class.new(preserved_object_id: preserved_object.id)).not_to be_valid
    expect(described_class.new(args)).to be_valid
  end

  it 'defines a status enum with the expected values' do
    is_expected.to define_enum_for(:status).with(
      'ok' => 0,
      'invalid_moab' => 1,
      'invalid_checksum' => 2,
      'online_moab_not_found' => 3,
      'unexpected_version_on_storage' => 4,
      'validity_unknown' => 6,
      'unreplicated' => 7,
      'replicated_copy_not_found' => 8
    )
  end

  context '#status=' do
    it "validation rejects a value if it does not match the enum" do
      expect { described_class.new(status: 654) }
        .to raise_error(ArgumentError, "'654' is not a valid status")
      expect { described_class.new(status: 'INVALID_MOAB') }
        .to raise_error(ArgumentError, "'INVALID_MOAB' is not a valid status")
    end

    it "will accept a symbol, but will always return a string" do
      expect(described_class.new(status: :invalid_moab).status).to eq 'invalid_moab'
    end
  end

  it { is_expected.to belong_to(:endpoint) }
  it { is_expected.to belong_to(:preserved_object) }
  it { is_expected.to have_db_index(:last_version_audit) }
  it { is_expected.to have_db_index(:last_moab_validation) }
  it { is_expected.to have_db_index(:last_checksum_validation) }
  it { is_expected.to have_db_index(:endpoint_id) }
  it { is_expected.to have_db_index(:preserved_object_id) }
  it { is_expected.to validate_presence_of(:endpoint) }
  it { is_expected.to validate_presence_of(:preserved_object) }
  it { is_expected.to validate_presence_of(:version) }
  it { is_expected.to have_many(:archive_preserved_copies) }

  describe '#replicate!' do
    it 'raises if too large' do
      pc.size = 10_000_000_000
      expect { pc.replicate! }.to raise_error(RuntimeError, /too large/)
    end
    it 'raises if unsaved' do
      expect { described_class.new(size: 1).replicate! }.to raise_error(RuntimeError, /must be persisted/)
    end
    it 'passes druid and version to Zipmaker' do
      expect(ZipmakerJob).to receive(:perform_later).with(preserved_object.druid, pc.version)
      pc.replicate!
    end
  end

  describe '#validate_checksums!' do
    it 'passes self to ChecksumValidationJob' do
      expect(ChecksumValidationJob).to receive(:perform_later).with(pc)
      pc.validate_checksums!
    end
  end

  context 'delegation to s3_key' do
    it 'creates the s3_key correctly' do
      expect(pc.s3_key).to eq("ab/123/cd/4567/#{druid}.v0001.zip")
    end
  end

  describe '#druid_version_zip' do
    it 'creates an instance of DruidVersionZip' do
      expect(pc.druid_version_zip).to be_an_instance_of DruidVersionZip
    end
  end

  describe '#update_audit_timestamps' do
    it 'updates last_moab_validation time if moab_validated is true' do
      expect { pc.update_audit_timestamps(true, false) }.to change { pc.last_moab_validation }.from(nil)
    end
    it 'does not update last_moab_validation time if moab_validated is false' do
      expect { pc.update_audit_timestamps(false, false) }.not_to change { pc.last_moab_validation }.from(nil)
    end
    it 'updates last_version_audit time if version_audited is true' do
      expect { pc.update_audit_timestamps(false, true) }.to change { pc.last_version_audit }.from(nil)
    end
    it 'does not update last_version_audit time if version_audited is false' do
      expect { pc.update_audit_timestamps(false, false) }.not_to change { pc.last_version_audit }.from(nil)
    end
  end

  describe '#upd_audstamps_version_size' do
    it 'updates version' do
      expect { pc.upd_audstamps_version_size(false, 3, nil) }.to change { pc.version }.to(3)
    end
    it 'updates size if size is not nil' do
      expect { pc.upd_audstamps_version_size(false, 0, 123) }.to change { pc.size }.to(123)
    end
    it 'does not update size if size is nil' do
      expect { pc.upd_audstamps_version_size(false, 0, nil) }.not_to change(pc, :size)
    end

    it 'calls update_audit_timestamps with the appropriate params' do
      expect(pc).to receive(:update_audit_timestamps).with(false, true)
      pc.upd_audstamps_version_size(false, 3, nil)
    end
  end

  describe '#update_status' do
    it 'does nothing if the status has not changed' do
      ran_the_block = false
      pc.update_status(pc.status) { ran_the_block = true }
      expect(pc.status).to eq 'validity_unknown'
      expect(ran_the_block).to eq false
      expect(pc).not_to be_changed
    end

    it 'runs the block and updates the status if the status has changed' do
      ran_the_block = false
      pc.update_status('ok') { ran_the_block = true }
      expect(pc.status).to eq 'ok'
      expect(ran_the_block).to eq true
      expect(pc.status_changed?).to eq true
    end
  end

  describe '#matches_po_current_version?' do
    before { pc.version = 666 }

    it 'returns true when its version matches its preserved objects current version' do
      pc.preserved_object.current_version = 666
      expect(pc.matches_po_current_version?).to be true
    end

    it 'returns false when its version does not match its preserved objects current version' do
      pc.preserved_object.current_version = 777
      expect(pc.matches_po_current_version?).to be false
    end
  end

  describe '.least_recent_version_audit' do
    let!(:newer_timestamp_pc) do
      create(:preserved_copy, args.merge(version: 6, last_version_audit: (now - 1.day)))
    end
    let!(:older_timestamp_pc) do
      create(:preserved_copy, args.merge(version: 7, last_version_audit: (now - 2.days)))
    end
    let!(:future_timestamp_pc) do
      create(:preserved_copy, args.merge(version: 8, last_version_audit: (now + 1.day)))
    end

    it 'returns PreservedCopies with nils first, then old to new timestamps' do
      expect(described_class.least_recent_version_audit(now)).to eq [pc, older_timestamp_pc, newer_timestamp_pc]
    end
    it 'returns no PreservedCopies with future timestamps' do
      expect(described_class.least_recent_version_audit(now)).not_to include future_timestamp_pc
    end
  end

  describe '.normalize_date(timestamp)' do
    it 'given a String timestamp, returns a Time object' do
      expect(described_class.send(:normalize_date, '2018-01-22T18:54:48')).to be_a(Time)
    end
    it 'given a Time Object, returns equivalent Time object' do
      expect(described_class.send(:normalize_date, now)).to eq(now)
    end
    it 'given nil, raises TypeError' do
      expect { described_class.send(:normalize_date, nil) }.to raise_error(TypeError, /no implicit conversion/)
    end
    it 'given an unparseable date, raises ArgumentError' do
      expect { described_class.send(:normalize_date, 'an 6') }.to raise_error(ArgumentError, /no time information/)
    end
    it 'given day only returns a Time object' do
      expect(described_class.send(:normalize_date, '2018-02-02')).to be_a(Time)
    end
    it 'given a month only returns Time object' do
      expect(described_class.send(:normalize_date, 'April')).to be_a(Time)
    end
    it 'given a year only, raises ArgumentError' do
      expect { described_class.send(:normalize_date, '2014') }.to raise_error(ArgumentError, /argument out of range/)
    end
  end

  describe '.fixity_check_expired' do
    let(:fixity_ttl) { preserved_object.preservation_policy.fixity_ttl }
    let!(:old_check_pc1) do
      create(:preserved_copy, args.merge(version: 6, last_checksum_validation: now - (fixity_ttl * 2)))
    end
    let!(:old_check_pc2) do
      create(:preserved_copy, args.merge(version: 7, last_checksum_validation: now - fixity_ttl - 1.second))
    end
    let!(:recently_checked_pc1) do
      create(:preserved_copy, args.merge(version: 8, last_checksum_validation: now - fixity_ttl + 1.second))
    end
    let!(:recently_checked_pc2) do
      create(:preserved_copy, args.merge(version: 9, last_checksum_validation: now - (fixity_ttl * 0.1)))
    end

    before { pc.save! }

    it 'returns PreservedCopies that need fixity check, never checked first, then least-recently to most-recently' do
      expect(described_class.fixity_check_expired.to_a).to eq [pc, old_check_pc1, old_check_pc2]
    end
    it 'returns no PreservedCopies with timestamps indicating still-valid fixity check' do
      expect(described_class.fixity_check_expired).not_to include(recently_checked_pc1, recently_checked_pc2)
    end
  end

  context 'with a persisted object' do
    before { pc.save! }

    describe '.by_endpoint_name' do
      it 'returns the expected preserved copies' do
        expect(described_class.by_endpoint_name('fixture_sr1').length).to eq 1
        expect(described_class.by_endpoint_name('fixture_sr2')).to be_empty
        expect(described_class.by_endpoint_name('fixture_empty')).to be_empty
      end
    end

    describe '.by_storage_location' do
      it 'returns the expected preserved copies' do
        expect(described_class.by_storage_location('spec/fixtures/storage_root01/sdr2objects').length).to eq 1
        expect(described_class.by_storage_location('spec/fixtures/storage_root02/sdr2objects')).to be_empty
        expect(described_class.by_storage_location('spec/fixtures/empty/sdr2objects')).to be_empty
      end
    end

    describe '.by_druid' do
      it 'returns the expected preserved copies' do
        expect(described_class.by_druid(druid).length).to eq 1
        expect(described_class.by_druid('bj102hs9687')).to be_empty
      end
    end
  end

  # this is not intended to exhaustively test all permutations, but to highlight/test likely useful combos
  context 'chained scopes' do
    describe '.fixity_check_expired' do
      let(:endpoint2) { Endpoint.find_by(endpoint_name: 'fixture_sr2') }
      let!(:checked_before_threshold_pc1) do
        create(:preserved_copy, args.merge(version: 6, last_checksum_validation: now - 3.weeks))
      end
      let!(:checked_before_threshold_pc2) do
        create(:preserved_copy, args.merge(version: 7, last_checksum_validation: now - 7.01.days, endpoint: endpoint2))
      end
      let!(:recently_checked_pc1) do
        create(:preserved_copy, args.merge(version: 8, last_checksum_validation: now - 6.99.days))
      end
      let!(:recently_checked_pc2) do
        create(:preserved_copy, args.merge(version: 9, last_checksum_validation: now - 1.day, endpoint: endpoint2))
      end

      describe '.by_endpoint_name' do
        let(:pcs_ordered_by_query1) { described_class.fixity_check_expired.by_endpoint_name(endpoint.endpoint_name) }
        let(:pcs_ordered_by_query2) { described_class.fixity_check_expired.by_endpoint_name(endpoint2.endpoint_name) }

        it 'returns PreservedCopies with nils first, then old to new timestamps, only for the chosen storage root' do
          expect(pcs_ordered_by_query1).to eq [pc, checked_before_threshold_pc1]
          expect(pcs_ordered_by_query2).to eq [checked_before_threshold_pc2]
        end
        it 'returns no PreservedCopies with timestamps indicating fixity check in the last week' do
          expect(pcs_ordered_by_query1).not_to include recently_checked_pc1
          expect(pcs_ordered_by_query2).not_to include recently_checked_pc2
        end
      end

      describe '.by_storage_location' do
        let!(:pcs_ordered_by_query1) do
          described_class.fixity_check_expired.by_storage_location('spec/fixtures/storage_root01/sdr2objects')
        end
        let!(:pcs_ordered_by_query2) do
          described_class.fixity_check_expired.by_storage_location('spec/fixtures/storage_root02/sdr2objects')
        end

        it 'returns PreservedCopies with nils first, then old to new timestamps, only for the chosen storage root' do
          expect(pcs_ordered_by_query1).to eq [pc, checked_before_threshold_pc1]
          expect(pcs_ordered_by_query2).to eq [checked_before_threshold_pc2]
        end
        it 'returns no PreservedCopies with timestamps indicating fixity check in the last week' do
          expect(pcs_ordered_by_query1).not_to include recently_checked_pc1
          expect(pcs_ordered_by_query2).not_to include recently_checked_pc2
        end
      end
    end
  end

  describe '#create_archive_preserved_copies!' do
    let(:pc_version) { 3 }
    let(:archive_ep) { ArchiveEndpoint.find_by!(endpoint_name: 'mock_archive1') }
    let(:new_archive_ep) { create(:archive_endpoint, endpoint_name: 'mock_archive2') }

    it "creates pres copies that don't yet exist for the given version, but should" do
      expect { pc.create_archive_preserved_copies!(pc_version) }.to change {
        ArchiveEndpoint.which_need_archive_copy(druid, pc_version).to_a
      }.from([archive_ep]).to([])

      expect(ArchivePreservedCopy.by_druid(druid).count).to eq 1

      expect { pc.create_archive_preserved_copies!(pc_version - 1) }.to change {
        ArchiveEndpoint.which_need_archive_copy(druid, pc_version - 1).to_a
      }.from([archive_ep]).to([])
      expect(ArchivePreservedCopy.by_druid(druid).count).to eq 2

      expect(ArchivePreservedCopy.by_druid(druid).where(version: 1).count).to eq 0
    end

    it 'creates the pres copies so that they start with unreplicated status' do
      expect(pc.create_archive_preserved_copies!(pc_version).all?(&:unreplicated?)).to be true
    end

    it "creates pres copies that don't yet exist for the given endpoint, but should" do
      expect { pc.create_archive_preserved_copies!(pc_version) }.to change {
        ArchiveEndpoint.which_need_archive_copy(druid, pc_version).to_a
      }.from([archive_ep]).to([])
      expect(ArchivePreservedCopy.by_druid(druid).where(version: pc_version).count).to eq 1

      new_archive_ep.preservation_policies = [PreservationPolicy.default_policy]
      expect { pc.create_archive_preserved_copies!(pc_version) }.to change {
        ArchiveEndpoint.which_need_archive_copy(druid, pc_version).to_a
      }.from([new_archive_ep]).to([])
      expect(ArchivePreservedCopy.by_druid(druid).where(version: pc_version).count).to eq 2
    end

    it 'checks that version is in range' do
      [-1, 0, 4, 5].each do |version|
        exp_err_msg = "archive_vers (#{version}) must be between 0 and version (#{pc_version})"
        expect { pc.create_archive_preserved_copies!(version) }.to raise_error ArgumentError, exp_err_msg
      end

      (1..3).each do |version|
        expect { pc.create_archive_preserved_copies!(version) }.not_to raise_error
      end
    end
  end
end
