require 'rails_helper'

RSpec.describe Audit::CatalogToArchive do
  let(:zmv) { create(:zipped_moab_version) }
  let(:logger) { instance_double(Logger) }

  before do
    allow(described_class).to receive(:logger).and_return(logger)
    allow(logger).to receive(:error) # most test cases only care about a subset of the logged errors
  end

  context 'zip parts have not been created yet' do
    it 'logs an error indicating that zip parts have not beeen created yet' do
      expect(logger).to receive(:error).with("#{zmv.inspect}: no zip_parts exist yet for this ZippedMoabVersion")
      described_class.check_child_zip_part_attributes(zmv)
    end
  end

  context 'different parts have different expected parts_count values' do
    before do
      args = attributes_for(:zip_part)
      zmv.zip_parts.create!(
        [
          args.merge(status: 'ok', parts_count: 2, suffix: '.zip'),
          args.merge(status: 'ok', parts_count: 2, suffix: '.z01'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z02')
        ]
      )
    end

    it 'logs the discrepancy' do
      child_parts_counts = zmv.child_parts_counts
      exp_err_msg = "#{zmv.inspect}: there's variation in child part counts: #{child_parts_counts.to_a}"
      expect(logger).to receive(:error).with(exp_err_msg)
      described_class.check_child_zip_part_attributes(zmv)
    end
  end

  context 'parts_count is consistent across parts and with the actual number of zip parts' do
    before do
      args = attributes_for(:zip_part)
      zmv.zip_parts.create!(
        [
          args.merge(status: 'ok', parts_count: 3, suffix: '.zip'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z01'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z02')
        ]
      )
    end

    it "doesn't log parts_count errors" do
      expect(logger).not_to receive(:error).with(/there's variation in child part counts/)
      described_class.check_child_zip_part_attributes(zmv)
    end

    it "doesn't log an error about parts_count mismatching number of zip_parts" do
      expect(logger).not_to receive(:error).with(/stated parts count.*doesn't match actual parts count/)
      described_class.check_child_zip_part_attributes(zmv)
    end
  end

  context "parts_count is consistent across parts, but doesn't match the actual number of child parts" do
    before do
      args = attributes_for(:zip_part)
      zmv.zip_parts.create!(
        [
          args.merge(status: 'ok', parts_count: 3, suffix: '.zip'),
          args.merge(status: 'ok', parts_count: 3, suffix: '.z01')
        ]
      )
    end

    it 'logs the discrepancy' do
      expect(logger).to receive(:error).with(
        "#{zmv.inspect}: stated parts count (3) doesn't match actual parts count (2)"
      )
      described_class.check_child_zip_part_attributes(zmv)
    end
  end

  context 'zip parts have been created' do
    context 'some parts are unreplicated' do
      before do
        args = attributes_for(:zip_part)
        zmv.zip_parts.create!(
          [
            args.merge(status: 'unreplicated', parts_count: 3, suffix: '.zip'),
            args.merge(status: 'ok', parts_count: 3, suffix: '.z01'),
            args.merge(status: 'unreplicated', parts_count: 3, suffix: '.z02')
          ]
        )
      end

      it 'logs the unreplicated parts' do
        unreplicated_parts = zmv.zip_parts.where(suffix: ['.zip', '.z02'])
        msg = "#{zmv.inspect}: all parts should be replicated, but at least one is not: #{unreplicated_parts.to_a}"
        expect(logger).to receive(:error).with(msg)
        described_class.check_child_zip_part_attributes(zmv)
      end
    end
  end
end
