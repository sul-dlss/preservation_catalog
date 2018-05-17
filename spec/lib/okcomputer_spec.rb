require 'rails_helper'

describe 'OkComputer custom checks' do # rubocop:disable RSpec/DescribeClass
  subject { described_class.new }

  describe TablesHaveDataCheck do
    it { is_expected.to be_successful }
    context 'without data' do
      before { allow(PreservationPolicy).to receive(:select).with(:id).and_return([]) }
      it { is_expected.not_to be_successful }
    end
  end

  describe VersionAuditWindowCheck do
    it { is_expected.to be_successful }
    context 'with old data' do
      before { allow(PreservedCopy).to receive(:least_recent_version_audit).with(any_args).and_return([double]) }
      it { is_expected.not_to be_successful }
    end
  end

  describe DirectoryExistsCheck do
    it 'successful for existing directory' do
      expect(DirectoryExistsCheck.new(Settings.zip_storage)).to be_successful
    end
    it 'fails for a file' do
      zip_path = 'spec/fixtures/zip_storage/bj/102/hs/9687/bj102hs9687.v0001.zip'
      expect(DirectoryExistsCheck.new(zip_path)).not_to be_successful
    end
    it 'fails for non-existent directory' do
      expect(DirectoryExistsCheck.new('i-do-not-exist')).not_to be_successful
    end
  end

end
