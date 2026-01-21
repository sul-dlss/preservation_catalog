# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ZippedMoabVersion do
  let(:preserved_object) { create(:preserved_object) }
  let(:zmv) { create(:zipped_moab_version, preserved_object: preserved_object) }

  it 'is not valid without all required valid attributes' do
    expect(described_class.new).not_to be_valid
    expect(described_class.new(preserved_object: preserved_object)).not_to be_valid
    expect(zmv).to be_valid
  end

  describe '#total_part_size' do
    context 'there are no parts' do
      it 'returns 0' do
        expect(zmv.total_part_size).to eq(0)
      end
    end

    context 'there are parts' do
      before do
        args = attributes_for(:zip_part)
        zmv.zip_parts.create!(
          [
            args.merge(suffix: '.zip', size: 1234),
            args.merge(suffix: '.z01', size: 1234),
            args.merge(suffix: '.z02', size: 1234)
          ]
        )
      end

      it 'returns the sum of the part sizes' do
        expect(zmv.total_part_size).to eq(3702)
      end
    end
  end

  describe '#update_status_updated_at before save' do
    it 'sets status_updated_at if status has changed' do
      expect { zmv.ok! }.to(change(zmv, :status_updated_at))
    end

    it 'does not change status_updated_at if status has not changed' do
      expect { zmv.update!(zip_parts_count: 2) }.not_to(change(zmv, :status_updated_at))
    end
  end

  describe '#update_status_details before save' do
    before do
      zmv.update!(status_details: 'some details')
    end

    it 'clears status_details if status has changed but status_details has not changed' do
      expect { zmv.ok! }.to(change(zmv, :status_details).from('some details').to(nil))
    end

    it 'does not change status_details if status_details has changed' do
      expect { zmv.update(status: 'ok', status_details: 'new details') }
        .to(change(zmv, :status_details).from('some details').to('new details'))
    end

    it 'does not change status_details if status has not changed' do
      expect { zmv.update!(zip_parts_count: 2) }.not_to(change(zmv, :status_details))
    end
  end
end
