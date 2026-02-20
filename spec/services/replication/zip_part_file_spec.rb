# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ZipPartFile do
  subject(:file) { described_class.new(filename:) }

  let(:filename) { 'bj/102/hs/9687/bj102hs9687.v0001.zip' }

  before do
    allow(Settings).to receive(:zip_storage).and_return('spec/fixtures/zip_storage')
  end

  describe '#size' do
    it 'returns the size of the file' do
      expect(file.size).to eq(3)
    end
  end

  describe '#extname' do
    it 'returns the file extension' do
      expect(file.extname).to eq('.zip')
    end
  end
end
