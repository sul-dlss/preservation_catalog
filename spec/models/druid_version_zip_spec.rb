# frozen_string_literal: true

require 'rails_helper'

describe DruidVersionZip do
  # Some tests below will use the constructor that takes storage_location, because they are
  # testing behavior where a zip is being created from a Moab on disk.  For tests that don't
  # exercise that behavior, the parameter is omitted to test that it isn't needed.
  let(:dvz) { described_class.new(druid, version) }
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }

  describe '#base_key' do
    it 'returns filename without ext' do
      expect(dvz.base_key).to eq 'bj/102/hs/9687/bj102hs9687.v0001'
    end
  end

  describe '#s3_key' do
    it 'returns a tree path-based key' do
      expect(dvz.s3_key).to eq 'bj/102/hs/9687/bj102hs9687.v0001.zip'
    end

    context 'version is greater than 1' do
      let(:version) { 2 }

      it 'uses the right version in the path' do
        expect(dvz.s3_key).to eq 'bj/102/hs/9687/bj102hs9687.v0002.zip'
      end
    end
  end

  describe '#ensure_zip_directory' do
    it 'returns path if zip directory exists' do
      expect(dvz.ensure_zip_directory!.to_s).to eq '/tmp/bj/102/hs/9687/bj102hs9687.v0001.zip'
    end

    context 'zip directory does not exist' do
      before { FileUtils.rm_rf('/tmp/bj/102/hs/9687/') }

      it 'returns path by creating zip directory if does not exist' do
        expect(File).not_to exist('/tmp/bj/102/hs/9687/bj102hs9687.v0001.zip')
        expect { dvz.ensure_zip_directory! }.not_to raise_error
        expect(dvz.ensure_zip_directory!.to_s).to eq '/tmp/bj/102/hs/9687/bj102hs9687.v0001.zip'
      end
    end
  end

  describe '#file_path' do
    it 'returns a full path' do
      expect(dvz.file_path).to eq '/tmp/bj/102/hs/9687/bj102hs9687.v0001.zip'
    end
  end

  describe '#find_or_create_zip!' do
    let(:dvz) { described_class.new(druid, version, 'spec/fixtures/storage_root01/sdr2objects') }

    context 'there is a zip file already made, but it looks too small' do
      before do
        dvz.create_zip!
        File.open(dvz.file_path, 'w') { |f| f.write('pretend it is too small because zip binary silently omitted versionAdditions.xml') }
      end

      it 'raises an error indicating that the file in the zip temp space looks too small' do
        expect {
          dvz.find_or_create_zip!
        }.to raise_error(RuntimeError, 'zip already exists, but size (80) is smaller than the moab version size (1928387)!')
      end
    end

    context 'there is a zip file already made, and it passes the size check' do
      let(:version) { 3 }

      before { dvz.create_zip! }

      after { FileUtils.rm_rf('/tmp/bj') } # cleanup

      it 'updates atime and mtime on the zip file that is already there' do
        sleep(0.1) # sorta hate this, but sleep for a 1/10 s, to give a moment before checking atime/mtime (to prevent flappy test in CI).
        expect { dvz.find_or_create_zip! }.to(
          (change {
            File.stat(dvz.file_path).atime
          }).and(change {
            File.stat(dvz.file_path).mtime
          })
        )
      end

      it 'does not attempt to re-create the zip file' do
        expect(dvz).not_to receive(:create_zip!)
        dvz.find_or_create_zip!
      end
    end
  end

  describe '#create_zip!' do
    let(:dvz) { described_class.new(druid, version, 'spec/fixtures/storage_root01/sdr2objects') }
    let(:zip_path) { dvz.file_path }
    let(:version) { 3 } # v1 and v2 pre-existing

    after { FileUtils.rm_rf('/tmp/bj') } # cleanup

    context 'when zip size is less than the moab size' do
      let(:moab_version_size) { dvz.send(:moab_version_size) }
      let(:total_part_size) { moab_version_size / 2 }

      before do
        allow(dvz).to receive(:total_part_size).and_return(total_part_size)
      end

      it 'raises an error' do
        expect { dvz.create_zip! }.to raise_error(
          RuntimeError,
          /zip size \(#{total_part_size}\) is smaller than the moab version size \(#{moab_version_size}\)/
        )
      end

      it 'cleans up the zip file' do
        expect { dvz.create_zip! }.to raise_error(RuntimeError)
        expect(dvz.parts_and_checksums_paths).to be_empty
      end

      it 'handles errors from zip cleanup gracefully and includes cleanup error messages in the overall message' do
        cleanup_err_msg = "Errno::EACCES: Permission denied - No delete for you - #{dvz.file_path}"
        allow(File).to receive(:delete).with(Pathname.new(dvz.file_path)).and_raise(Errno::EACCES, cleanup_err_msg)
        expect { dvz.create_zip! }.to raise_error(RuntimeError, /#{cleanup_err_msg}/m)
      end

      it 'does not interfere with zip files created for other versions' do
        dvz_v2 = described_class.new(druid, version - 1, 'spec/fixtures/storage_root01/sdr2objects')
        dvz_v2.create_zip!
        expect { dvz.create_zip! }.to raise_error(RuntimeError)
        expect(dvz_v2.parts_and_checksums_paths.sort).to eq [Pathname.new(dvz_v2.file_path), Pathname.new(dvz_v2.file_path + '.md5')]
      end
    end

    context 'when it succeeds' do
      after { File.delete(zip_path) }

      it 'produces the expected zip file' do
        expect(File).not_to exist(zip_path)
        expect { dvz.create_zip! }.not_to raise_error
        expect(File).to exist(zip_path)
      end

      it 'produces the expected md5 file' do
        md5_path = zip_path + '.md5'
        expect(File).not_to exist(md5_path)
        expect { dvz.create_zip! }.not_to raise_error
        expect(File).to exist(md5_path)
      end

      # we `list` a given filepath out of the zip, `unzip` exits w/ 0 only when found
      it 'produced zip has expected structure' do
        techmd = 'bj102hs9687/v0003/data/metadata/technicalMetadata.xml'
        dvz.create_zip!
        _, status = Open3.capture2e("unzip -lq #{zip_path} #{techmd}")
        expect(status).to be_success
        _, status = Open3.capture2e("unzip -lq #{zip_path} bj/102/hs/9687/#{techmd}")
        expect(status).not_to be_success
      end

      it 'calls check_moab_version_readability! before attempting to create the zip' do
        # This checks that we only attempt zip creation after checking to see that all files are readable.
        expect(dvz).to receive(:check_moab_version_readability!).ordered.and_call_original
        expect(Open3).to receive(:capture2e).with(dvz.zip_command, chdir: dvz.work_dir.to_s).ordered.and_call_original
        expect { dvz.create_zip! }.not_to raise_error
        expect(File).to exist(zip_path)
      end
    end

    context 'when the moab version directory to be zipped has unreadable files' do
      let(:unreadable_filename) { 'spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0003/manifests/versionInventory.xml' }

      it 'allows the error to bubble up when stat is unsuccessfully called on a file in the moab version' do
        allow(File).to receive(:stat).and_call_original
        expect(File).to receive(:stat).with(unreadable_filename).and_raise(Errno::EACCES, 'no file for you')
        expect { dvz.create_zip! }.to raise_error(Errno::EACCES, /no file for you/)
      end
    end

    context 'for every part' do
      before do
        allow(dvz).to receive(:zip_split_size).and_return('1m')
        allow(dvz).to receive(:zip_size_ok?).and_return(true)
      end

      after { dvz.part_paths.each { |path| File.delete(path) } }

      let(:version) { 1 }

      it 'creates md5' do
        dvz.part_paths.each { |path| expect(File).not_to exist(path) }
        expect { dvz.create_zip! }.not_to raise_error
        dvz.part_paths.each { |path| expect(File).to exist(path) }
      end
    end

    describe 'zip command' do
      before { allow(dvz).to receive(:zip_command).and_return(zip_command) }

      context 'when inpath is incorrect' do
        let(:zip_command) { "zip -r0X -s 10g #{zip_path} /wrong/path" }

        it 'raises error' do
          expect { dvz.create_zip! }.to raise_error(RuntimeError, %r{zipmaker failure.*/wrong/path}m)
        end
      end

      context 'when options are unsupported' do
        let(:zip_command) { "zip --fantasy #{zip_path} #{druid}/v0003" }

        it 'raises error' do
          expect { dvz.create_zip! }.to raise_error(RuntimeError, /Invalid command arguments.*fantasy/)
        end
      end

      context 'if the utility "moved"' do
        let(:zip_command) { "zap -r0X -s 10g #{zip_path} #{druid}/v0003" }

        it 'raises error' do
          expect { dvz.create_zip! }.to raise_error(Errno::ENOENT, /No such file/)
        end
      end
    end
  end

  describe '#expected_part_keys' do
    it 'raises for invalid integer' do
      expect { dvz.expected_part_keys(0) }.to raise_error ArgumentError
    end

    it 'lists the files expected' do
      expect(dvz.expected_part_keys(1)).to eq ['bj/102/hs/9687/bj102hs9687.v0001.zip']
      expect(dvz.expected_part_keys(2)).to eq [
        'bj/102/hs/9687/bj102hs9687.v0001.zip',
        'bj/102/hs/9687/bj102hs9687.v0001.z01'
      ]
      one_oh_one = dvz.expected_part_keys(101)
      expect(one_oh_one.count).to eq(101)
      expect(one_oh_one.last).to eq('bj/102/hs/9687/bj102hs9687.v0001.z100')
    end
  end

  describe '#hex_to_base64' do
    it 'returns base64-encoded value' do
      expect(dvz.hex_to_base64('4f98f59e877ecb84ff75ef0fab45bac5')).to eq 'T5j1nod+y4T/de8Pq0W6xQ=='
      expect(dvz.hex_to_base64('d41d8cd98f00b204e9800998ecf8427e')).to eq '1B2M2Y8AsgTpgAmY7PhCfg=='
    end
  end

  describe '#moab_version_path' do
    context 'storage_location is not available' do
      it 'raises an error' do
        expect { dvz.moab_version_path }.to raise_error("cannot determine moab_version_path for #{druid} v#{version}, storage_location not provided")
      end
    end

    context 'storage_location is provided in the constructor' do
      let(:dvz) { described_class.new(druid, version, 'spec/fixtures/storage_root01/sdr2objects') }

      it 'returns authoritative druid version location' do
        expect(dvz.moab_version_path)
          .to eq 'spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001'
      end
    end
  end

  describe '#part_keys' do
    let(:druid) { 'dc048cw1328' }

    before do
      FileUtils.rm_rf('/tmp/dc') # prep dir
      dvz.ensure_zip_directory!
      %w[zip z01 z02 z03 z04].each do |f|
        FileUtils.touch("/tmp/dc/048/cw/1328/dc048cw1328.v0001.#{f}")
      end
    end

    after { FileUtils.rm_rf('/tmp/dc') } # cleanup

    it 'lists the multiple files produced' do
      expect(dvz.part_keys).to all(be_a String)
      expect(dvz.part_keys).to include(
        'dc/048/cw/1328/dc048cw1328.v0001.zip',
        'dc/048/cw/1328/dc048cw1328.v0001.z01',
        'dc/048/cw/1328/dc048cw1328.v0001.z02',
        'dc/048/cw/1328/dc048cw1328.v0001.z03',
        'dc/048/cw/1328/dc048cw1328.v0001.z04'
      )
      expect(dvz.part_keys.count).to eq 5
    end
  end

  describe '#part_paths' do # zip splits
    let(:druid) { 'dc048cw1328' } # fixture is 4.9 MB
    let(:dvz) { described_class.new(druid, version, 'spec/fixtures/storage_root02/sdr2objects') }

    before do
      allow(dvz).to receive(:zip_split_size).and_return('1m')
      FileUtils.rm_rf('/tmp/dc') # prep clean dir
    end

    after { FileUtils.rm_rf('/tmp/dc') } # cleanup

    it 'lists the multiple files produced' do
      dvz.create_zip!
      expect(dvz.part_paths).to all(be_a Pathname)
      expect(dvz.part_paths.map(&:to_s)).to include(
        '/tmp/dc/048/cw/1328/dc048cw1328.v0001.zip',
        '/tmp/dc/048/cw/1328/dc048cw1328.v0001.z01',
        '/tmp/dc/048/cw/1328/dc048cw1328.v0001.z04'
      )
      expect(dvz.part_paths.count).to eq 5
    end
  end

  describe '#v_version' do
    let(:version) { 1 }

    it 'returns 3 zero-padded string of the version' do
      expect(dvz.v_version).to eq 'v0001'
    end

    context 'two digit version' do
      let(:version) { 34 }

      it 'returns 2 zero-padded string of the version' do
        expect(dvz.v_version).to eq 'v0034'
      end
    end
  end

  describe '#work_dir' do
    let(:dvz) { described_class.new(druid, version, 'spec/fixtures/storage_root01/sdr2objects') }

    it 'returns Pathname directory where the zip command is executed' do
      expect(dvz.work_dir.to_s).to eq 'spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687'
    end
  end

  describe '#zip_command' do
    let(:zip_path) { '/tmp/bj/102/hs/9687/bj102hs9687.v0001.zip' }

    it 'returns zip string to execute for this druid/version' do
      expect(dvz.zip_command).to eq "zip -r0X -s 10g #{zip_path} bj102hs9687/v0001"
    end
  end

  describe '#zip_version' do
    it 'calls fetch_zip_version only once' do
      dvz.zip_version
      expect(dvz).not_to receive(:fetch_zip_version)
      dvz.zip_version
    end
  end

  describe '#zip_version_regexp' do
    subject { dvz.send(:zip_version_regexp) }

    it { is_expected.to match('This is Zip 3.0 (July 5th 2008), by Info-ZIP.') }
    it { is_expected.to match('This is Zip 5.0.2 (April 19th 2021), by Cyberdyne II') }
    it { is_expected.not_to match(%[Copyright (c) 1990-2008 Info-ZIP - Type 'zip "-L"' for software license.]) }
    it { is_expected.not_to match('bzip2, a block-sorting file compressor.  Version 1.0.6, 6-Sept-2010.') }
  end

  describe '#fetch_zip_version' do
    it 'gets version from the system zip' do
      expect(dvz.send(:fetch_zip_version)).to match(/^Zip \d+\.\d+/)
    end
  end

  describe '#zip_storage' do
    it 'returns Pathname to location where the zip file is to be created' do
      expect(dvz.zip_storage.to_s).to eq '/tmp'
    end
  end

  describe '#check_moab_version_readability!' do
    let(:dvz) { described_class.new(druid, version, 'spec/fixtures/storage_root01/sdr2objects') }
    let(:v1_moab_files) do
      %w[
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/content/eric-smith-dissertation-augmented.pdf
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/content/eric-smith-dissertation.pdf
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/contentMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/descMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/identityMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/provenanceMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/relationshipMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/rightsMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/technicalMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/versionMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/fileInventoryDifference.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/manifestInventory.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/signatureCatalog.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/versionAdditions.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/versionInventory.xml
      ]
    end

    it 'calls File.stat on each file in the moab version directory' do
      allow(File).to receive(:stat)
      v1_moab_files.each { |filename| expect(File).to receive(:stat).with(filename) }
      dvz.send(:check_moab_version_readability!)
    end
  end
end
