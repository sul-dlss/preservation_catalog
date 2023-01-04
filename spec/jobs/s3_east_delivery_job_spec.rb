# frozen_string_literal: true

require 'rails_helper'

describe AwsEastDeliveryJob do
  it 'descends from AbstractDeliveryJob' do
    expect(described_class.new).to be_an(AbstractDeliveryJob)
  end

  it 'uses its own queue' do
    expect(described_class.new.queue_name).to eq 's3_us_east_1_delivery'
  end
end
