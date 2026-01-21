# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabRecord do
  let(:druid) { 'ab123cd4567' }
  let(:preserved_object) { create(:preserved_object, druid: druid) }
  let(:status) { 'validity_unknown' }
  let(:moab_record_version) { 1 }
  let(:args) do # default constructor params
    {
      preserved_object: preserved_object,
      version: moab_record_version,
      status: status
    }
  end

  # some tests assume the MoabRecord and PresevedObject exist before the vars are referenced.  the eager instantiation of moab_record will cause
  # instantiation of preserved_object, since moab_record depends on it (via args).
  let!(:moab_record) { create(:moab_record, args) }
  let(:now) { Time.now.utc }

  it 'is not valid without all required valid attributes' do
    po = create(:preserved_object)
    expect(described_class.new).not_to be_valid
    expect(described_class.new(preserved_object_id: po.id)).not_to be_valid
    expect(described_class.new(args.merge(preserved_object_id: po.id, moab_storage_root_id: MoabStorageRoot.first.id, size: 1))).to be_valid
  end

  it 'defines a status enum with the expected values' do
    is_expected.to define_enum_for(:status).with_values(
      'ok' => 0,
      'invalid_moab' => 1,
      'invalid_checksum' => 2,
      'moab_on_storage_not_found' => 3,
      'unexpected_version_on_storage' => 4,
      'validity_unknown' => 6
    )
  end

  describe '#status=' do
    it 'validation rejects a value if it does not match the enum' do
      expect { described_class.new(status: 654) }
        .to raise_error(ArgumentError, "'654' is not a valid status")
      expect { described_class.new(status: 'INVALID_MOAB') }
        .to raise_error(ArgumentError, "'INVALID_MOAB' is not a valid status")
    end

    it 'accepts a symbol, but will always return a string' do
      expect(described_class.new(status: :invalid_moab).status).to eq 'invalid_moab'
    end
  end

  it { is_expected.to belong_to(:moab_storage_root) }
  it { is_expected.to belong_to(:preserved_object) }
  it { is_expected.to have_db_index(:last_version_audit) }
  it { is_expected.to have_db_index(:last_moab_validation) }
  it { is_expected.to have_db_index(:last_checksum_validation) }
  it { is_expected.to have_db_index(:moab_storage_root_id) }
  it { is_expected.to have_db_index(:preserved_object_id) }
  it { is_expected.to validate_presence_of(:version) }
  it { is_expected.to validate_uniqueness_of(:preserved_object_id) }

  describe '#validate_checksums!' do
    it 'passes self to Audit::ChecksumValidationJob' do
      expect(Audit::ChecksumValidationJob).to receive(:perform_later).with(moab_record)
      moab_record.validate_checksums!
    end
  end

  describe '#update_audit_timestamps' do
    it 'updates last_moab_validation time if moab_validated is true' do
      expect { moab_record.update_audit_timestamps(true, false) }.to change(moab_record, :last_moab_validation).from(nil)
    end

    it 'does not update last_moab_validation time if moab_validated is false' do
      expect { moab_record.update_audit_timestamps(false, false) }.not_to change(moab_record, :last_moab_validation).from(nil)
    end

    it 'updates last_version_audit time if version_audited is true' do
      expect { moab_record.update_audit_timestamps(false, true) }.to change(moab_record, :last_version_audit).from(nil)
    end

    it 'does not update last_version_audit time if version_audited is false' do
      expect { moab_record.update_audit_timestamps(false, false) }.not_to change(moab_record, :last_version_audit).from(nil)
    end
  end

  describe '#upd_audstamps_version_size' do
    it 'updates version' do
      expect { moab_record.upd_audstamps_version_size(false, 3, nil) }.to change(moab_record, :version).to(3)
    end

    it 'updates size if size is not nil' do
      expect { moab_record.upd_audstamps_version_size(false, 0, 123) }.to change(moab_record, :size).to(123)
    end

    it 'does not update size if size is nil' do
      expect { moab_record.upd_audstamps_version_size(false, 0, nil) }.not_to change(moab_record, :size)
    end

    it 'calls update_audit_timestamps with the appropriate params' do
      expect(moab_record).to receive(:update_audit_timestamps).with(false, true)
      moab_record.upd_audstamps_version_size(false, 3, nil)
    end
  end

  describe '#matches_preserved_object_current_version?' do
    before { moab_record.version = 666 }

    it 'returns true when its version matches its preserved objects current version' do
      moab_record.preserved_object.current_version = 666
      expect(moab_record.matches_preserved_object_current_version?).to be true
    end

    it 'returns false when its version does not match its preserved objects current version' do
      moab_record.preserved_object.current_version = 777
      expect(moab_record.matches_preserved_object_current_version?).to be false
    end
  end

  describe '#migrate_moab' do
    let(:target_storage_root) { create(:moab_storage_root) }
    let(:yesterday) { now - 1.day }
    let(:migrating_moab_record) do
      # pretend we're moving a nice recently validated moab
      create(
        :moab_record,
        {
          preserved_object: create(:preserved_object),
          status: 'ok',
          version: 1,
          status_details: 'status now ok',
          last_moab_validation: yesterday,
          last_checksum_validation: yesterday,
          last_version_audit: yesterday
        }
      )
    end

    it 'updates the current storage root, records the old one, and clears audit info' do
      expect(migrating_moab_record.from_moab_storage_root).to be_nil
      orig_storage_root = migrating_moab_record.moab_storage_root

      migrating_moab_record.migrate_moab(target_storage_root).save!
      migrating_moab_record.reload

      expect(migrating_moab_record.moab_storage_root).to eq(target_storage_root)
      expect(migrating_moab_record.from_moab_storage_root).to eq(orig_storage_root)
      expect(migrating_moab_record.status).to eq('validity_unknown')
      expect(migrating_moab_record.status_details).to be_nil
      expect(migrating_moab_record.last_moab_validation).to be_nil
      expect(migrating_moab_record.last_checksum_validation).to be_nil
      expect(migrating_moab_record.last_version_audit).to be_nil
    end

    it 'queues a checksum validation job' do
      allow(Audit::ChecksumValidationJob).to receive(:perform_later).with(moab_record)
      migrating_moab_record.migrate_moab(target_storage_root).save!
      expect(Audit::ChecksumValidationJob).to have_received(:perform_later).with(moab_record)
    end
  end

  context 'ordered (by last version_audited) and unordered version_audit_expired' do
    let!(:newer_timestamp_moab_rec) do
      create(:moab_record, args.merge(version: 6, last_version_audit: (now - 1.day), preserved_object: create(:preserved_object)))
    end
    let!(:older_timestamp_moab_rec) do
      create(:moab_record, args.merge(version: 7, last_version_audit: (now - 2.days), preserved_object: create(:preserved_object)))
    end
    let!(:future_timestamp_moab_rec) do
      create(:moab_record, args.merge(version: 8, last_version_audit: (now + 1.day), preserved_object: create(:preserved_object)))
    end

    describe '.version_audit_expired' do
      it 'returns MoabRecords with nils and MoabRecords < given date (not orded by last_version_audit)' do
        expect(described_class.version_audit_expired.sort).to eq [moab_record, newer_timestamp_moab_rec, older_timestamp_moab_rec]
      end

      it 'returns no MoabRecords with future timestamps' do
        expect(described_class.version_audit_expired).not_to include future_timestamp_moab_rec
      end
    end
  end

  describe 'enforcement of uniqueness on druid (PreservedObject) across all storage roots' do
    context 'at the model level' do
      it 'must be unique' do
        expect {
          create(:moab_record, preserved_object_id: preserved_object.id,
                               moab_storage_root: create(:moab_storage_root))
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'at the db level' do
      it 'must be unique' do
        dup_moab_record = described_class.new(preserved_object_id: preserved_object.id,
                                              moab_storage_root: create(:moab_storage_root),
                                              status: status,
                                              version: moab_record_version)
        expect { dup_moab_record.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  context 'ordered (by fixity_check_expired) and unordered fixity_check_expired methods' do
    let(:fixity_ttl) { Settings.preservation_policy.fixity_ttl }
    let!(:fixity_expired_moab_rec1) do
      create(:moab_record, args.merge(version: 6,
                                      last_checksum_validation: now - (fixity_ttl * 2),
                                      preserved_object: create(:preserved_object)))
    end
    let!(:fixity_expired_moab_rec2) do
      create(:moab_record, args.merge(version: 7,
                                      last_checksum_validation: now - fixity_ttl - 1.second,
                                      preserved_object: create(:preserved_object)))
    end
    let!(:recently_checked_moab_rec1) do
      create(:moab_record, args.merge(version: 8,
                                      last_checksum_validation: now - fixity_ttl + 1.second,
                                      preserved_object: create(:preserved_object)))
    end
    let!(:recently_checked_moab_rec2) do
      create(:moab_record, args.merge(version: 9,
                                      last_checksum_validation: now - (fixity_ttl * 0.1),
                                      preserved_object: create(:preserved_object)))
    end

    describe '.fixity_check_expired' do
      it 'returns MoabRecords that need fixity check' do
        expect(described_class.fixity_check_expired.to_a.sort).to eq [moab_record, fixity_expired_moab_rec1, fixity_expired_moab_rec2]
      end

      it 'returns no MoabRecords with timestamps indicating still-valid fixity check' do
        expect(described_class.fixity_check_expired).not_to include(recently_checked_moab_rec1, recently_checked_moab_rec2)
      end
    end
  end

  context 'with a persisted object' do
    describe '.by_druid' do
      it 'returns the expected MoabRecords' do
        expect(described_class.by_druid(druid).length).to eq 1
        expect(described_class.by_druid('bj102hs9687')).to be_empty # bj102hs9687 from preserved_object factory
      end
    end

    describe '.by_storage_root' do
      it 'returns the expected MoabRecord when chained with by_druid' do
        expect(described_class.by_druid(druid).length).to eq 1
        expect(described_class.by_druid(druid).by_storage_root(moab_record.moab_storage_root).length).to eq 1
      end
    end
  end

  describe '.after_save callback' do
    before { allow(Audit::ChecksumValidationJob).to receive(:perform_later).and_call_original } # undo rails_helper block

    it 'does not call validate_checksums when status is unchanged' do
      moab_record.size = 234
      expect(moab_record).not_to receive(:validate_checksums!)
      moab_record.save!
    end

    it 'does calls validate_checksums when status is validity_unknown' do
      moab_record.ok! # object starts out with validity_unknown status
      expect(moab_record).to receive(:validate_checksums!)
      moab_record.validity_unknown!
    end
  end

  describe '#daily_check_count' do
    before do
      allow(described_class).to receive(:count).and_return(1000)
    end

    it 'calculates the number of objects to check per day' do
      expect(described_class.daily_check_count).to eq 11
    end
  end
end
