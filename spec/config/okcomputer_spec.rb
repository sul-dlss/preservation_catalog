# frozen_string_literal: true

require 'rails_helper'

describe 'OkComputer custom checks' do # rubocop:disable RSpec/DescribeClass
  subject { described_class.new }

  describe TablesHaveDataCheck do
    it { is_expected.to be_successful }

    context 'without data' do
      before { allow(MoabStorageRoot).to receive(:select).with(:id).and_return([]) }

      it { is_expected.not_to be_successful }
    end
  end

  describe VersionAuditWindowCheck do
    it { is_expected.to be_successful }

    context 'with old data' do
      before { allow(CompleteMoab).to receive(:version_audit_expired).with(any_args).and_return([double]) }

      it { is_expected.not_to be_successful }
    end
  end

  describe DirectoryExistsCheck do
    it 'successful for existing directory' do
      expect(described_class.new(Settings.zip_storage)).to be_successful
    end

    it 'successful for existing directory with minumum number of subfolders' do
      expect(described_class.new(Rails.root, 5)).to be_successful
    end

    it 'fails for existing directory with fewer than the minumum number of subfolders' do
      expect(described_class.new(Rails.root, 500)).not_to be_successful
    end

    it 'fails for a file' do
      zip_path = 'spec/fixtures/zip_storage/bj/102/hs/9687/bj102hs9687.v0001.zip'
      expect(described_class.new(zip_path)).not_to be_successful
    end

    it 'fails for non-existent directory' do
      expect(described_class.new('i-do-not-exist')).not_to be_successful
    end
  end
end
