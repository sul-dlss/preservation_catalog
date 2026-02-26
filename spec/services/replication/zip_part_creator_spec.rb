# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ZipPartCreator do
  subject(:creator) { described_class.new(pathfinder:) }

  let(:pathfinder) do
    Replication::ZipPartPathfinder.new(
      druid: 'bj102hs9687',
      version: 3,
      storage_location: 'spec/fixtures/storage_root01/sdr2objects'
    )
  end

  describe '#create!' do
    context 'when zip file size is less than the Moab version files size' do
      before do
        allow(creator).to receive(:total_part_size).and_return(256) # rubocop:disable RSpec/SubjectStub
      end

      it 'raises Replication::Errors::ZipmakerFailure exception' do
        expect { creator.create! }.to raise_error(Replication::Errors::ZipmakerFailure)
      end
    end

    context 'when an unexpected error is raised' do
      let(:zip_output) { 'something went wrong' }
      let(:zip_status) { instance_double(Process::Status, success?: false) }

      before do
        allow(Open3).to receive(:capture2e).and_return([zip_output, zip_status])
        allow(Replication::ZipPartCleaner).to receive(:clean!)
      end

      it 'cleans up files from the failed creation' do
        expect { creator.create! }.to raise_error(Replication::Errors::ZipmakerFailure)
        expect(Replication::ZipPartCleaner).to have_received(:clean!).once
      end
    end
  end
end
