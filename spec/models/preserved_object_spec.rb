require 'rails_helper'

RSpec.describe PreservedObject, type: :model do
  let!(:preservation_policy) { PreservationPolicy.create!(preservation_policy_name: 'default') }

  let(:required_attributes) do
    {
      druid: 'ab123cd45678',
      current_version: 1,
      preservation_policy: preservation_policy
    }
  end
  let(:addl_attributes) do
    {
      size: 1
    }
  end

  it { is_expected.to belong_to(:preservation_policy) }
  it { is_expected.to have_many(:preservation_copies) }
  it { is_expected.to have_db_index(:druid) }
  it { is_expected.to have_db_index(:preservation_policy_id) }

  context 'validation' do
    it 'is valid with required attributes' do
      po = PreservedObject.create(required_attributes)
      expect(po).to be_valid
    end
    it 'is valid with required and optional attributes' do
      po = PreservedObject.create(required_attributes.merge(addl_attributes))
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
    it 'enforces unique constraint on druid' do
      PreservedObject.create(required_attributes)
      exp_err_msg = 'Validation failed: Druid has already been taken'
      expect do
        PreservedObject.create!(required_attributes)
      end.to raise_error(ActiveRecord::RecordInvalid, exp_err_msg)
    end
  end

  describe '.update' do
    context 'entry already exists' do
      let!(:po) { PreservedObject.create(required_attributes) } # po saved to db

      shared_examples 'entry exists' do |incoming_version|
        it 'updates entry with timestamp' do
          before_time = po.updated_at
          PreservedObject.update('ab123cd45678', current_version: incoming_version)
          expect(po.reload.updated_at).to be > before_time
        end
        it 'logs at debug level' do
          allow(Rails.logger).to receive(:debug)
          expect(Rails.logger).to receive(:debug).with("update #{po.druid} called and object exists")
          PreservedObject.update(po.druid, current_version: incoming_version)
        end
        it 'returns true' do
          expect(PreservedObject.update(po.druid, current_version: incoming_version)).to eq true
        end
      end

      context 'incoming and db versions match' do
        it "entry version stays the same" do
          PreservedObject.update('ab123cd45678', current_version: 1)
          expect(po.reload.current_version).to eq 1
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:info).with("#{po.druid} incoming version is equal to db version")
          PreservedObject.update('ab123cd45678', current_version: 1)
        end
        it_behaves_like 'entry exists', 1
      end

      context 'incoming version is greater than db version' do
        it "updates entry with incoming version" do
          PreservedObject.update('ab123cd45678', current_version: 5)
          expect(po.reload.current_version).to eq 5
        end
        it 'updates entry with size if included' do
          PreservedObject.update('ab123cd45678', current_version: 5, size: 666)
          expect(po.reload.size).to eq 666
        end
        it 'retains old size if incoming size is nil' do
          expect(po.size).to eq nil
          PreservedObject.update('ab123cd45678', current_version: 4, size: 666)
          expect(po.reload.size).to eq 666
          PreservedObject.update('ab123cd45678', current_version: 5)
          expect(po.reload.size).to eq 666
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:info).with("#{po.druid} incoming version is greater than db version")
          PreservedObject.update('ab123cd45678', current_version: 5)
        end
        it_behaves_like 'entry exists', 5
      end

      context 'incoming version is smaller than db version' do
        it "entry version stays the same" do
          PreservedObject.update('ab123cd45678', current_version: 0)
          expect(po.reload.current_version).to eq 1
        end
        it "logs at error level" do
          expect(Rails.logger).to receive(:error).with("#{po.druid} incoming version smaller than db version")
          PreservedObject.update('ab123cd45678', current_version: 0)
        end
        it_behaves_like 'entry exists', 0
      end
    end
    context 'entry does not exist (yet)' do
      let(:po) do
        po = PreservedObject.find_by(druid: required_attributes[:druid])
        po.destroy if po
        PreservedObject.new(required_attributes) # po not saved to db
      end

      after(:all) do
        po = PreservedObject.find_by(druid: 'ab123cd45678')
        po.destroy if po
      end

      it 'creates entry' do
        expect(PreservedObject.exists?(druid: po.druid)).to be false
        PreservedObject.update(po.druid, current_version: 1, preservation_policy: preservation_policy)
        expect(PreservedObject.exists?(druid: po.druid)).to be true
      end
      it 'includes size in entry if passed in' do
        PreservedObject.update(po.druid, current_version: 1, size: 666, preservation_policy: preservation_policy)
        expect(PreservedObject.exists?(druid: po.druid, size: 666)).to be true
      end
      it 'logs at warn level' do
        expect(Rails.logger).to receive(:warn).with("update #{po.druid} called but object not found; writing object")
        PreservedObject.update(po.druid)
      end
      it 'returns false' do
        expect(PreservedObject.update(po.druid)).to eq false
      end
    end
  end
end
