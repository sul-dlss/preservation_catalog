require 'rails_helper'

RSpec.describe HostSettings do
  it 'depends on Settings.storage_root_map' do
    expect(Settings.storage_root_map).to be
  end

  describe '.storage_roots' do
    it 'gets the correct values' do
      expect(described_class).to receive(:storage_root_lookup_name).and_call_original
      expect(described_class.storage_roots.to_h).to eq(fixture_sr1: 'spec/fixtures/storage_root01',
                                                       fixture_sr2: 'spec/fixtures/storage_root02',
                                                       fixture_sr3: 'spec/fixtures/checksum_root01',
                                                       fixture_empty: 'spec/fixtures/empty')
    end

    context 'on unrecognized systems' do
      it 'does not bork, just returns empty hash' do
        allow(described_class).to receive(:storage_root_lookup_name).and_return('foobar123')
        expect { described_class.storage_roots }.not_to raise_error
        expect(described_class.storage_roots).to eq({})
      end
    end
  end

  describe '.storage_root_lookup_name' do
    it "returns 'default' when not in production" do
      expect(described_class.storage_root_lookup_name).to eq('default')
    end
    it 'returns parsed hostname when in production' do
      expect(Rails.env).to receive(:production?).and_return(true)
      expect(described_class).to receive(:parsed_hostname).and_return('preservation_catalog_prod_a')
      expect(described_class.storage_root_lookup_name).to eq('preservation_catalog_prod_a')
    end
  end

  describe '.parsed_hostname' do
    it 'makes hyphens into underscores and trims the domain down' do
      expect(Socket).to receive(:gethostname).and_return('preservation-catalog-prod-a.stanford.edu')
      expect(described_class.parsed_hostname).to eq('preservation_catalog_prod_a')
    end
  end
end
