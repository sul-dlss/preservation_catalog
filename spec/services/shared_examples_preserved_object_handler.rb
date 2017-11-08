RSpec.shared_examples "attributes validated" do |method_sym|
  let(:bad_druid) { '666' }
  let(:bad_version) { 'vv666' }
  let(:bad_size) { '-666' }
  let(:bad_storage_dir) { '' }
  let(:bad_druid_msg) { 'Druid is invalid' }
  let(:bad_version_msg) { 'Incoming version is not a number' }
  let(:bad_size_msg) { 'Incoming size must be greater than 0' }
  let(:bad_storage_dir_msg) { "Endpoint can't be blank" }

  context 'returns' do
    let!(:result) do
      po_handler = described_class.new(bad_druid, bad_version, bad_size, bad_storage_dir)
      po_handler.send(method_sym)
    end

    it '1 result' do
      expect(result).to be_an_instance_of Array
      expect(result.size).to eq 1
    end
    it 'INVALID_ARGUMENTS' do
      expect(result).to include(a_hash_including(PreservedObjectHandler::INVALID_ARGUMENTS))
    end
    context 'result message includes' do
      let(:msg) { result.first[PreservedObjectHandler::INVALID_ARGUMENTS] }
      let(:exp_msg_prefix) { "PreservedObjectHandler(#{bad_druid}, #{bad_version}, #{bad_size}, #{bad_storage_dir})" }

      it "prefix" do
        expect(msg).to match(Regexp.escape("#{exp_msg_prefix} encountered validation error(s): "))
      end
      it "druid error" do
        expect(msg).to match(bad_druid_msg)
      end
      it "version error" do
        expect(msg).to match(bad_version_msg)
      end
      it "size error" do
        expect(msg).to match(bad_size_msg)
      end
      it "storage dir error" do
        expect(msg).to match(bad_storage_dir_msg)
      end
    end
  end

  it 'bad druid error is written to Rails log' do
    po_handler = described_class.new(bad_druid, incoming_version, incoming_size, storage_dir)
    err_msg = "PreservedObjectHandler(#{bad_druid}, #{incoming_version}, #{incoming_size}, #{storage_dir}) encountered validation error(s): [\"#{bad_druid_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad version error is written to Rails log' do
    po_handler = described_class.new(druid, bad_version, incoming_size, storage_dir)
    err_msg = "PreservedObjectHandler(#{druid}, #{bad_version}, #{incoming_size}, #{storage_dir}) encountered validation error(s): [\"#{bad_version_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad size error is written to Rails log' do
    po_handler = described_class.new(druid, incoming_version, bad_size, storage_dir)
    err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{bad_size}, #{storage_dir}) encountered validation error(s): [\"#{bad_size_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad storage directory is written to Rails log' do
    po_handler = described_class.new(druid, incoming_version, incoming_size, bad_storage_dir)
    err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{bad_storage_dir}) encountered validation error(s): [\"#{bad_storage_dir_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
end

RSpec.shared_examples 'druid not in catalog' do |method_sym|
  let(:druid) { 'rr111rr1111' }
  let(:exp_msg) { "#{exp_msg_prefix} #<ActiveRecord::RecordNotFound: Couldn't find PreservedObject> db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    # FIXME: couldn't figure out how to put next line into its own test
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(exp_msg)}/)
    po_handler.send(method_sym)
  end

  it 'OBJECT_DOES_NOT_EXIST error' do
    code = PreservedObjectHandler::OBJECT_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => exp_msg))
  end
end

RSpec.shared_examples 'PreservedCopy does not exist' do |method_sym|
  before do
    PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
  end
  let(:exp_msg) { "#{exp_msg_prefix} #<ActiveRecord::RecordNotFound: foo> db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    # FIXME: couldn't figure out how to put next line into its own test
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(exp_msg)}/)
    po = instance_double(PreservedObject)
    allow(po).to receive(:current_version).and_return(2)
    allow(po).to receive(:current_version=)
    allow(po).to receive(:changed?).and_return(true)
    allow(po).to receive(:save!)
    allow(PreservedObject).to receive(:find_by!).and_return(po)
    # allow(PreservedObject).to receive(:find_by!).and_return(instance_double(PreservedObject))
    allow(PreservedCopy).to receive(:find_by!).and_raise(ActiveRecord::RecordNotFound, 'foo')
    po_handler.send(method_sym)
  end

  it 'OBJECT_DOES_NOT_EXIST error' do
    code = PreservedObjectHandler::OBJECT_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => exp_msg))
  end
end
