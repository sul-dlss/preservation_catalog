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
end
