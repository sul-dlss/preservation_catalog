# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabStorageDirectory do
  let(:storage_dir) { @fixtures.join('storage_root01/moab_storage_trunk') }

  before(:all) do
    @temp = Pathname.new(File.dirname(__FILE__)).join('temp')
    @temp.mkpath
    @temp = @temp.realpath
    @fixtures = Pathname.new(File.dirname(__FILE__)).join('..', 'fixtures')
    @fixtures.mkpath
    @fixtures = @fixtures.realpath
    @obj = 'jq937jp0017'
    @druid = "druid:#{@obj}"
    @data = @fixtures.join('data', @obj)
    @derivatives = @fixtures.join('derivatives')
    @manifests = @derivatives.join('manifests')
    @packages = @derivatives.join('packages')
    @ingests = @derivatives.join('ingests')
    @reconstructs = @derivatives.join('reconstructs')
    @vname = [nil, 'v0001', 'v0002', 'v0003']

    # Inventory data directories
    (1..3).each do |version|
      manifest_dir = @manifests.join(@vname[version])
      manifest_dir.mkpath
      inventory = Moab::FileInventory.new(type: 'version', digital_object_id: @druid, version_id: version)
      inventory.inventory_from_directory(@data.join(@vname[version]))
      inventory.write_xml_file(manifest_dir)
    end

    # Derive signature catalogs from inventories
    (1..3).each do |version|
      manifest_dir = @manifests.join(@vname[version])
      manifest_dir.mkpath
      inventory = Moab::FileInventory.read_xml_file(manifest_dir, 'version')
      catalog = case version
                when 1
                  Moab::SignatureCatalog.new(digital_object_id: inventory.digital_object_id)
                else
                  Moab::SignatureCatalog.read_xml_file(@manifests.join(@vname[version - 1]))
                end
      catalog.update(inventory, @data.join(@vname[version]))
      catalog.write_xml_file(manifest_dir)
    end

    # Generate version addition reports for all version inventories
    (2..3).each do |version|
      manifest_dir = @manifests.join(@vname[version])
      manifest_dir.mkpath
      inventory = Moab::FileInventory.read_xml_file(manifest_dir, 'version')
      catalog = Moab::SignatureCatalog.read_xml_file(@manifests.join(@vname[version - 1]))
      additions = catalog.version_additions(inventory)
      additions.write_xml_file(manifest_dir)
    end

    # Generate difference reports
    (2..3).each do |version|
      manifest_dir = @manifests.join(@vname[version])
      manifest_dir.mkpath
      old_inventory = Moab::FileInventory.read_xml_file(@manifests.join(@vname[version - 1]), 'version')
      new_inventory = Moab::FileInventory.read_xml_file(@manifests.join(@vname[version]), 'version')
      differences = Moab::FileInventoryDifference.new.compare(old_inventory, new_inventory)
      differences.write_xml_file(manifest_dir)
    end
    manifest_dir = @manifests.join('all')
    manifest_dir.mkpath
    old_inventory = Moab::FileInventory.read_xml_file(@manifests.join(@vname[1]), 'version')
    new_inventory = Moab::FileInventory.read_xml_file(@manifests.join(@vname[3]), 'version')
    differences = Moab::FileInventoryDifference.new.compare(old_inventory, new_inventory)
    differences.write_xml_file(manifest_dir)

    # Generate packages from inventories and signature catalogs
    (1..3).each do |version|
      package_dir = @packages.join(@vname[version])
      next if package_dir.join('data').exist?
      data_dir = @data.join(@vname[version])
      inventory = Moab::FileInventory.read_xml_file(@manifests.join(@vname[version]), 'version')
      catalog = case version
                when 1
                  Moab::SignatureCatalog.new(digital_object_id: inventory.digital_object_id)
                else
                  Moab::SignatureCatalog.read_xml_file(@manifests.join(@vname[version - 1]))
                end
      Moab::Bagger.new(inventory, catalog, package_dir).fill_bag(:depositor, data_dir)
    end

    # Store packages in a pseudo repository
    (1..3).each do |version|
      object_dir = @ingests.join(@obj)
      object_dir.mkpath
      unless object_dir.join("v000#{version}").exist?
        bag_dir = @packages.join(@vname[version])
        Moab::StorageObject.new(@druid, object_dir).ingest_bag(bag_dir)
      end
    end

    # Generate reconstructed versions from pseudo repository
    (1..3).each do |version|
      bag_dir = @reconstructs.join(@vname[version])
      unless bag_dir.exist?
        object_dir = @ingests.join(@obj)
        Moab::StorageObject.new(@druid, object_dir).reconstruct_version(version, bag_dir)
      end
    end

    ## Re-Generate packages from inventories and signature catalogs
    ## because output contents were moved into psuedo repository
    # (1..3).each do |version|
    #  package_dir  = @packages.join(@vname[version])
    #  unless package_dir.join('data').exist?
    #    data_dir = @data.join(@vname[version])
    #    inventory = Moab::FileInventory.read_xml_file(@manifests.join(@vname[version]),'version')
    #    case version
    #      when 1
    #        catalog = Moab::SignatureCatalog.new(:digital_object_id => inventory.digital_object_id)
    #      else
    #        catalog = Moab::SignatureCatalog.read_xml_file(@manifests.join(@vname[version-1]))
    #    end
    #    Moab::StorageObject.package(inventory,catalog,data_dir,package_dir)
    #  end
    # end
  end

  describe '.find_moab_paths' do
    it 'passes a druid as the first parameter to the block it gets' do
      described_class.find_moab_paths(storage_dir) do |druid, _path, _path_match_data|
        expect(druid).to match(/[[:lower:]]{2}\d{3}[[:lower:]]{2}\d{4}/)
      end
    end

    it 'passes a valid file path as the second parameter to the block it gets' do
      described_class.find_moab_paths(storage_dir) do |_druid, path, _path_match_data|
        expect(File.exist?(path)).to be true
      end
    end

    it 'passes a MatchData object as the third parameter to the block it gets' do
      described_class.find_moab_paths(storage_dir) do |_druid, _path, path_match_data|
        expect(path_match_data).to be_a_kind_of(MatchData)
      end
    end
  end

  describe '.list_moab_druids' do
    let(:druids) { described_class.list_moab_druids(storage_dir) }

    it 'lists the expected druids in the fixture directory' do
      expect(druids.sort).to eq %w[bj102hs9687 bz514sm9647 jj925bx9565]
    end

    it 'returns only the expected druids in the fixture directory' do
      expect(druids.length).to eq 3
    end
  end

  describe '.storage_dir_regexp' do
    it 'caches the regular expression used to match druid paths under a given directory' do
      expect(Regexp).to receive(:new).once.and_call_original
      described_class.send(:storage_dir_regexp, 'foo')
      described_class.send(:storage_dir_regexp, 'foo')
    end
  end
end
