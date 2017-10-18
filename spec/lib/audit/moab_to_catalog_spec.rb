require_relative "../../../lib/audit/moab_to_catalog.rb"
RSpec.describe MoabToCatalog do
  describe ".check_moab_to_catalog_existence" do
    before do
      PreservationPolicy.seed_from_config
    end

    let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }
    let(:subject) { described_class.check_moab_to_catalog_existence(storage_dir) }

    it "call 'find_moab_paths' with appropriate argument" do
      allow(MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      subject
      expect(MoabStorageDirectory).to have_received(:find_moab_paths).with(storage_dir)
    end
    context "determine create or update method with expected values" do
      let(:expected_argument_list) do
        [
          { druid: 'bj102hs9687', storage_root_current_version: 3 },
          { druid: 'bz514sm9647', storage_root_current_version: 3 },
          { druid: 'jj925bx9565', storage_root_current_version: 2 }
        ]
      end

      before do
        expected_argument_list.each do |arg_hash|
          po_handler = instance_double('PreservedObjectHandler')
          arg_hash[:po_handler] = po_handler
          allow(PreservedObjectHandler).to receive(:new).with(
            arg_hash[:druid],
            arg_hash[:storage_root_current_version],
            instance_of(Integer),
            storage_dir
          ).and_return(po_handler)
        end
      end
      it "call #create if object does not exist" do
        # mock that the object doesn't exist in catalog yet
        expected_argument_list.each do |arg_hash|
          allow(PreservedObject).to receive(:exists?).with(druid: arg_hash[:druid]).and_return(false)
          allow(arg_hash[:po_handler]).to receive(:create)
        end
        subject
        expected_argument_list.each do |arg_hash|
          expect(PreservedObject).to have_received(:exists?).with(druid: arg_hash[:druid])
          expect(arg_hash[:po_handler]).to have_received(:create)
        end
      end
      it "call #update if object exists" do
        # mock that the object does exist in catalog already
        expected_argument_list.each do |arg_hash|
          allow(PreservedObject).to receive(:exists?).with(druid: arg_hash[:druid]).and_return(true)
          allow(arg_hash[:po_handler]).to receive(:update)
        end
        subject
        expected_argument_list.each do |arg_hash|
          expect(PreservedObject).to have_received(:exists?).with(druid: arg_hash[:druid])
          expect(arg_hash[:po_handler]).to have_received(:update)
        end
      end
    end

    it "return correct number of results" do
      expect(subject.count).to eq 3
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
