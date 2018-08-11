require 'rails_helper'

RSpec.describe Audit::CatalogToArchive do
  let(:zmv) { create(:zipped_moab_version) }
  let(:cm) { zmv.complete_moab }
  let(:logger) { instance_double(Logger) }
  let(:results) { AuditResults.new(cm.preserved_object.druid, nil, cm.moab_storage_root, "CatalogToArchive") }
  let(:version) { zmv.version }
  let(:endpoint_name) { zmv.zip_endpoint.endpoint_name }
  let(:result_prefix) do
    "CatalogToArchive(#{cm.preserved_object.druid}, #{cm.moab_storage_root.name}) #{version} on #{endpoint_name}"
  end

  before do
    allow(described_class).to receive(:logger).and_return(logger)

    # TODO: can get rid of this when you switch to testing at the result code level
    allow(logger).to receive(:add) # most test cases only care about a subset of the logged errors
    allow(Dor::WorkflowService).to receive(:update_workflow_error_status)
  end

  after { results.report_results(logger) }

  context 'zip parts have not been created yet' do
    it 'logs an error indicating that zip parts have not beeen created yet' do
      expect(logger).to receive(:add).with(
        Logger::WARN, "#{result_prefix}: no zip_parts exist yet for this ZippedMoabVersion"
      )
      described_class.check_child_zip_part_attributes(zmv, results)
    end

    it 'returns false' do
      expect(described_class.check_child_zip_part_attributes(zmv, results)).to be(false)
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
      exp_err_msg = "#{result_prefix}: ZippedMoabVersion has variation in child parts_counts: #{child_parts_counts}"
      expect(logger).to receive(:add).with(Logger::ERROR, exp_err_msg)
      described_class.check_child_zip_part_attributes(zmv, results)
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
      expect(logger).not_to receive(:add).with(Logger::ERROR, /ZippedMoabVersion has variation in child parts_counts/)
      described_class.check_child_zip_part_attributes(zmv, results)
    end

    it "doesn't log an error about parts_count mismatching number of zip_parts" do
      expect(logger).not_to receive(:add).with(
        Logger::ERROR, /stated parts count.*doesn't match actual number of zip parts rows/
      )
      described_class.check_child_zip_part_attributes(zmv, results)
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
      expect(logger).to receive(:add).with(
        Logger::ERROR,
        "#{result_prefix}: ZippedMoabVersion stated parts count (3) doesn't match actual number of zip parts rows (2)"
      )
      described_class.check_child_zip_part_attributes(zmv, results)
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
        msg = "#{result_prefix}: not all ZippedMoabVersion parts are replicated yet: #{unreplicated_parts.to_a}"
        expect(logger).to receive(:add).with(Logger::WARN, msg)
        described_class.check_child_zip_part_attributes(zmv, results)
      end

      it 'returns true' do
        expect(described_class.check_child_zip_part_attributes(zmv, results)).to be(true)
      end
    end
  end
end
