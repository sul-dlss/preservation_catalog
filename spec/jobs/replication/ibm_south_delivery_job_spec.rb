# frozen_string_literal: true

require 'rails_helper'

describe Replication::IbmSouthDeliveryJob do
  it 'descends from Replication::AbstractDeliveryJob' do
    expect(described_class.new).to be_an(Replication::AbstractDeliveryJob)
  end

  it 'uses its own queue' do
    expect(described_class.new.queue_name).to eq 'ibm_us_south_delivery'
  end
end
