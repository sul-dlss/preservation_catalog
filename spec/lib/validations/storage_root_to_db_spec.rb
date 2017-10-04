require 'spec_helper'
require_relative "../../../lib/validations/storage_root_to_db.rb"

describe "storage root to db" do
  let(:storage_dir) { 'spec/fixtures/moab_storage_root' }
  let(:subject) { StorageRootToDB.check_online_to_db_existence(storage_dir) }

  it "should call 'find_moab_paths' with appropriate argument" do 
    allow(MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
    subject
    expect(MoabStorageDirectory).to have_received(:find_moab_paths).with(storage_dir)
  end

  it "should call 'update_or_create' with the expected values" do 
    expected_argument_list = [
      {druid: 'bj102hs9687', storage_root_current_version: 3, storage_root_size: 2012695},
      {druid: 'bp628nk4868', storage_root_current_version: 1, storage_root_size: 453769},
      {druid: 'bz514sm9647', storage_root_current_version: 3, storage_root_size: 277588},
      {druid: 'dc048cw1328', storage_root_current_version: 2, storage_root_size: 5178784},
      {druid: 'jj925bx9565', storage_root_current_version: 2, storage_root_size: 6601408}
    ]
    expected_argument_list.each do |arg_hash|
      po_handler = instance_double(PreservedObjectHandler)
      allow(PreservedObjectHandler).to receive(:new).with(arg_hash[:druid], arg_hash[:storage_root_current_version], arg_hash[:storage_root_size]).and_return(po_handler)
      expect(po_handler).to receive(:update_or_create)
    end
    subject    
  end

  it "should return correct number of results" do
    expect(subject.count).to eq 5
  end

  it "storage directory doesn't exist (misspelling, read write permissions)" do 
    expect{StorageRootToDB.check_online_to_db_existence('spec/fixtures/moab_strge_root')}.to raise_error(SystemCallError, /No such file or directory/)
  end

  it "storage directory exists but it is empty" do
    storage_dir = 'spec/fixtures/empty'
    expect(StorageRootToDB.check_online_to_db_existence(storage_dir)).to eq []
  end


end

