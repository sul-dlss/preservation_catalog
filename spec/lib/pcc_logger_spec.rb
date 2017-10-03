require 'rails_helper'
require 'spec_helper'

describe PCCLogger do
  before do
    allow(Rails.logger).to receive(:add)
  end

  it 'Calls the regular Rails logger' do
    described_class.log(Logger::ERROR, 'a random log message')
    expect(Rails.logger).to have_received(:add).with(Logger::ERROR, anything)
  end

  it 'Includes the druid if given' do
    described_class.log(Logger::ERROR, 'a random log message', 'druid:fq552dp4190')
    expect(Rails.logger).to have_received(:add).with(Logger::ERROR, /druid:fq552dp4190/)
  end

  it 'Logs messages in a reasonable-to-parse format' do
    described_class.log(Logger::ERROR, 'a random log message', 'druid:fq552dp4190')
    expect(Rails.logger).to have_received(:add)
      .with(Logger::ERROR,
            /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})\s(druid:\w{11})?\s(.*)/)

  end
end
