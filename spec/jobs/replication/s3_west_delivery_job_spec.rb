# frozen_string_literal: true

require 'rails_helper'

describe Replication::S3WestDeliveryJob do
  it 'descends from Replication::AbstractDeliveryJob' do
    expect(described_class.new).to be_an(Replication::AbstractDeliveryJob)
  end

  it 'uses its own queue' do
    expect(described_class.new.queue_name).to eq 's3_us_west_2_delivery'
  end
end
