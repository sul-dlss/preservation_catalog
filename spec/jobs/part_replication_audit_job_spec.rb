require 'rails_helper'

describe PartReplicationAuditJob, type: :job do
  let(:cm) { create(:complete_moab, version: 2) }
  let(:job) { described_class.new(cm, endpoint) }
  let(:endpoint) { cm.zipped_moab_versions.first.zip_endpoint }
  let(:logger) { instance_double(Logger) }

  before do
    allow(Audit::CatalogToArchive).to receive(:logger).and_return(logger)
  end

  describe '#queue_as' do
    it 'builds the queue name' do
      expect(job.queue_name).to eq("part_audit_#{endpoint.endpoint_name}")
    end

    context 'with a different endpoint' do
      let(:endpoint) { create(:zip_endpoint, endpoint_name: 'north_foobar') }

      it 'adapts the queue name' do
        expect(job.queue_name).to eq('part_audit_north_foobar')
      end
    end
  end

  describe '#perform' do
    let(:zmv1) { cm.zipped_moab_versions.where(zip_endpoint: endpoint).first }
    let(:zmv2) { cm.zipped_moab_versions.where(zip_endpoint: endpoint).second }
    let(:results) { job.send(:new_results, cm) }

    it 'only checks parts for one endpoint' do
      other_ep = create(:zip_endpoint)
      other_zmv = cm.zipped_moab_versions.find_by!(zip_endpoint: other_ep)
      count = cm.zipped_moab_versions.where(zip_endpoint: endpoint).count
      expect(job).to receive(:check_child_zip_part_attributes).with(ZippedMoabVersion, AuditResults).exactly(count).times
      expect(job).not_to receive(:check_child_zip_part_attributes).with(other_zmv, AuditResults)
      job.perform(cm, endpoint)
    end

    it 'builds results from sub-checks' do
      allow(job).to receive(:new_results).with(cm).and_return(results)
      allow(job).to receive(:check_child_zip_part_attributes).with(zmv2, AuditResults)
      expect(job).to receive(:check_child_zip_part_attributes).with(zmv1, AuditResults).and_return(true)
      expect(PreservationCatalog::S3::Audit).to receive(:check_aws_replicated_zipped_moab_version).with(zmv1, AuditResults)
      expect(PreservationCatalog::S3::Audit).not_to receive(:check_aws_replicated_zipped_moab_version).with(zmv2, AuditResults)
      expect(results).to receive(:report_results)
      job.perform(cm, endpoint)
    end
  end
end
