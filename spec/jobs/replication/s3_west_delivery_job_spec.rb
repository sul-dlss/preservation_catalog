# frozen_string_literal: true

require 'rails_helper'

describe Replication::S3WestDeliveryJob do
  it 'descends from Replication::DeliveryJobBase' do
    expect(described_class.new).to be_an(Replication::DeliveryJobBase)
  end

  it 'uses its own queue' do
    expect(described_class.new.queue_name).to eq 'replication_aws_us_west_2_delivery'
  end
end
