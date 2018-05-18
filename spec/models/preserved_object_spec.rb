require 'rails_helper'

RSpec.describe PreservedObject, type: :model do
  let!(:preservation_policy) { PreservationPolicy.default_policy }

  let(:required_attributes) do
    {
      druid: 'ab123cd4567',
      current_version: 1,
      preservation_policy: preservation_policy
    }
  end

  it { is_expected.to belong_to(:preservation_policy) }
  it { is_expected.to have_many(:preserved_copies) }
  it { is_expected.to have_db_index(:druid) }
  it { is_expected.to have_db_index(:preservation_policy_id) }
  it { is_expected.to validate_presence_of(:druid) }
  it { is_expected.to validate_presence_of(:current_version) }

  context 'validation' do
    it 'is valid with required attributes' do
      po = PreservedObject.create(required_attributes)
      expect(po).to be_valid
    end
    it 'is not valid without attributes' do
      expect(PreservedObject.new).not_to be_valid
    end
    it 'is not valid without a druid' do
      expect(PreservedObject.new(current_version: 1)).not_to be_valid
    end
    it 'is not valid without a current_version' do
      expect(PreservedObject.new(druid: 'ab123cd45678')).not_to be_valid
    end
    it 'enforces unique constraint on druid (model level)' do
      PreservedObject.create(required_attributes)
      exp_err_msg = 'Validation failed: Druid has already been taken'
      expect do
        PreservedObject.create!(required_attributes)
      end.to raise_error(ActiveRecord::RecordInvalid, exp_err_msg)
    end
    it 'enforces unique constraint on druid (db level)' do
      PreservedObject.create(required_attributes)
      dup_po = PreservedObject.new
      dup_po.druid = 'ab123cd4567'
      dup_po.current_version = 2
      dup_po.preservation_policy = preservation_policy
      expect { dup_po.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '.normalize_druid_name' do
    context 'druid with prefix created ex. (druid:xx000xx0000)' do
      before do
        po_with_prefix1 = create(:preserved_object, druid: 'druid:bb123cd4567')
        create(:preserved_copy, preserved_object: po_with_prefix1, endpoint: Endpoint.first)
        po_with_prefix2 = create(:preserved_object, druid: 'druid:ef891gh5300')
        create(:preserved_copy, preserved_object: po_with_prefix2, endpoint: Endpoint.first)
      end

      context 'matching record already exists' do
        before do
          po = create(:preserved_object, druid: 'bb123cd4567')
          create(:preserved_copy, preserved_object: po, endpoint: Endpoint.first)
        end

        it 'delete record w/ druid prefix' do
          expect(PreservedObject.where(druid: 'druid:bb123cd4567')).to exist
          expect(PreservedObject.where(druid: 'bb123cd4567')).to exist
          PreservedObject.normalize_druid_name
          expect(PreservedObject.where(druid: 'bb123cd4567')).to exist
          expect(PreservedObject.where(druid: 'druid:bb123cd4567')).not_to exist
        end
      end
      context 'matching record does not exist' do
        it 'updates bb123cd4567' do
          expect(PreservedObject.where(druid: 'druid:bb123cd4567')).to exist
          expect(PreservedObject.where(druid: 'bb123cd4567')).not_to exist
          PreservedObject.normalize_druid_name
          expect(PreservedObject.where(druid: 'druid:bb123cd4567')).not_to exist
          expect(PreservedObject.where(druid: 'bb123cd4567')).to exist
        end
        it 'updates ef891gh5300' do
          expect(PreservedObject.where(druid: 'druid:ef891gh5300')).to exist
          expect(PreservedObject.where(druid: 'ef891gh5300')).not_to exist
          PreservedObject.normalize_druid_name
          expect(PreservedObject.where(druid: 'ef891gh5300')).to exist
          expect(PreservedObject.where(druid: 'druid:ef891gh5300')).not_to exist
        end
      end
      context 'rolls back transaction' do
        before do
          po = create(:preserved_object, druid: 'bb123cd4567')
          create(:preserved_copy, preserved_object: po, endpoint: Endpoint.first)
        end

        it 'pres obj is not deleted if pres copy cannot be deleted' do
          po_to_delete = PreservedObject.where(druid: 'druid:bb123cd4567')
          allow(PreservedObject).to receive(:where).with("druid LIKE 'druid:%'").and_return(po_to_delete)
          allow(po_to_delete.first).to receive(:destroy).and_raise(ActiveRecord::ConnectionTimeoutError)
          expect { PreservedObject.normalize_druid_name }.to raise_error
          allow(PreservedObject).to receive(:where).and_call_original
          expect(PreservedObject.where(druid: 'druid:bb123cd4567')).to exist
          expect(PreservedObject.where(druid: 'bb123cd4567')).to exist
        end
      end
    end
  end
end
