require 'rails_helper'

describe ZipmakerJob, type: :job do
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:moab_version_path) { Moab::StorageServices.object_version_path(druid, version) }
  let(:zip_path) { "spec/fixtures/transfers/bj/102/hs/9687/#{druid}#{format('.v%04d.zip', version)}" }

  before do
    allow(PlexerJob).to receive(:perform_later).with(any_args)
    allow(Settings).to receive(:zip_storage).and_return('spec/fixtures/transfers')
  end

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  it 'invokes PlexerJob' do
    expect(PlexerJob).to receive(:perform_later).with(druid, version)
    described_class.perform_now(druid, version)
  end

  context 'zip already exists in zip storage' do

    it 'does not create a zip' do
      expect(File).to exist(zip_path)
      expect(described_class).not_to receive(:create_zip!)
      described_class.perform_now(druid, version)
    end
  end

  context 'zip is not yet in zip storage' do
    let(:version) { 2 }

    after { File.delete(zip_path) }

    it 'zips up the druid version into zip storage' do
      described_class.perform_now(druid, version)
      expect(File).to exist(zip_path)
    end
  end

  describe '.create_zip!' do
    let(:version) { 2 }

    context 'succeeds in zipping the binary' do
      it 'does not raise an error' do
        expect { described_class.create_zip!(zip_path, moab_version_path) }.not_to raise_error
        File.delete(zip_path)
      end
    end

    context 'fails to zip the binary' do
      context 'when inpath is incorrect' do
        it 'raises error' do
          expect { described_class.create_zip!(zip_path, 'bar') }.to raise_error(RuntimeError, /zipmaker failure/)
        end
      end
      context 'when options are unsupported' do
        it 'raises error' do
          allow(described_class).to receive(:zip_command).and_return("zip -a #{zip_path} #{moab_version_path}")
          expect { described_class.create_zip!(zip_path, moab_version_path) }
            .to raise_error(RuntimeError, /zipmaker failure/)
        end
      end
      context 'if the utility "moved"' do
        it 'raises error' do
          allow(described_class).to receive(:zip_command)
            .and_return("zap -vr0X -s 10g #{zip_path} #{moab_version_path}")
          expect { described_class.create_zip!(zip_path, moab_version_path) }
            .to raise_error(Errno::ENOENT, /No such file/)
        end
      end
    end

    describe '.zip_command' do
      it 'returns a string representing the command to zip' do
        expect(described_class.zip_command(zip_path, moab_version_path))
          .to eq "zip -vr0X -s 10g #{zip_path} #{moab_version_path}"
      end
    end
  end
end
