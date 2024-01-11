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

  describe RabbitQueueExistsCheck do
    let(:bunny_conn) { instance_double(Bunny::Session) }
    let(:queue_name1) { 'foo.first_queue' }
    let(:queue_name2) { 'foo.second_queue' }

    before do
      allow(bunny_conn).to receive_messages(start: bunny_conn, status: :open, close: true)
      allow(bunny_conn).to receive(:queue_exists?).with(queue_name1).and_return(queue_exists1)
      allow(bunny_conn).to receive(:queue_exists?).with(queue_name2).and_return(queue_exists2)
      allow(Bunny).to receive(:new).and_return(bunny_conn)
    end

    context 'when the expected queues are present' do
      let(:queue_exists1) { true }
      let(:queue_exists2) { true }

      it 'succeeds if the expected queue exists' do
        expect(described_class.new([queue_name1, queue_name2])).to be_successful
      end
    end

    context 'when a queue is missing' do
      let(:queue_exists1) { true }
      let(:queue_exists2) { false }

      it 'succeeds if the expected queue exists' do
        expect(described_class.new([queue_name1, queue_name2])).not_to be_successful
      end
    end
  end
end
