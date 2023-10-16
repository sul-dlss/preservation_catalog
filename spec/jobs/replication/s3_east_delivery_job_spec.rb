# frozen_string_literal: true

require 'rails_helper'

describe Replication::S3EastDeliveryJob do
  it 'descends from Replication::DeliveryJobBase' do
    expect(described_class.new).to be_an(Replication::DeliveryJobBase)
  end

  it 'uses its own queue' do
    expect(described_class.new.queue_name).to eq 'replication_s3_east_delivery'
  end
end
