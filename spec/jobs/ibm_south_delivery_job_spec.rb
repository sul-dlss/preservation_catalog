# frozen_string_literal: true

require 'rails_helper'

describe IbmSouthDeliveryJob, type: :job do
  it 'descends from AbstractDeliveryJob' do
    expect(described_class.new).to be_an(AbstractDeliveryJob)
  end

  it 'uses its own queue' do
    expect(described_class.new.queue_name).to eq 'ibm_us_south_delivery'
  end
end