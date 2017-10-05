require_relative "../../../lib/audit/moab_to_catalog.rb"
RSpec.describe MoabToCatalog do
  describe ".check_moab_to_catalog_existence" do
    before do
      PreservationPolicy.seed_from_config
    end

    let(:storage_dir) { 'spec/fixtures/moab_storage_trunk' }
    let(:subject) { described_class.check_moab_to_catalog_existence(storage_dir) }

    it "call 'find_moab_paths' with appropriate argument" do
      allow(MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      subject
      expect(MoabStorageDirectory).to have_received(:find_moab_paths).with(storage_dir)
    end

    it "call 'update_or_create' with the expected values" do
      expected_argument_list = [
        { druid: 'bj102hs9687', storage_root_current_version: 3 },
        { druid: 'bp628nk4868', storage_root_current_version: 1 },
        { druid: 'bz514sm9647', storage_root_current_version: 3 },
        { druid: 'dc048cw1328', storage_root_current_version: 2 },
        { druid: 'jj925bx9565', storage_root_current_version: 2 }
      ]

      # set up po_handler for each arg_hash
      expected_argument_list.each do |arg_hash|
        po_handler = instance_double('PreservedObjectHandler')
        arg_hash[:po_handler] = po_handler
        allow(PreservedObjectHandler).to receive(:new).with(
          arg_hash[:druid],
          arg_hash[:storage_root_current_version],
          instance_of(Integer)
        ).and_return(po_handler)
        allow(po_handler).to receive(:update_or_create)
      end

      subject
      expected_argument_list.each { |arg_hash| expect(arg_hash[:po_handler]).to have_received(:update_or_create) }
    end

    it "return correct number of results" do
      expect(subject.count).to eq 5
    end

    it "storage directory doesn't exist (misspelling, read write permissions)" do
      expect { described_class.check_moab_to_catalog_existence('spec/fixtures/moab_strge_root') }.to raise_error(
        SystemCallError, /No such file or directory/
      )
    end

    it "storage directory exists but it is empty" do
      storage_dir = 'spec/fixtures/empty'
      expect(described_class.check_moab_to_catalog_existence(storage_dir)).to eq []
    end

  end
end
