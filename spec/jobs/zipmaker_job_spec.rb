require 'rails_helper'

describe ZipmakerJob, type: :job do
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:moab_version_path) { Moab::StorageServices.object_version_path(druid, version) }
  let(:zip_path) { "spec/fixtures/transfers/bj/102/hs/9687/#{druid}#{format('.v%04d.zip', version)}" }
  let(:job) do
    described_class.new(druid, version).tap { |j| j.zip = DruidVersionZip.new(druid, version) }
  end

  before do
    allow(PlexerJob).to receive(:perform_later).with(any_args)
    allow(Settings).to receive(:zip_storage).and_return('spec/fixtures/transfers')
  end

  it 'descends from DruidVersionJobBase' do
    expect(described_class.new).to be_a(DruidVersionJobBase)
  end

  it 'invokes PlexerJob' do
    expect(PlexerJob).to receive(:perform_later).with(druid, version, Hash)
    described_class.perform_now(druid, version)
  end

  context 'zip already exists in zip storage' do
    it 'does not create a zip' do
      expect(File).to exist(zip_path)
      expect(job).not_to receive(:create_zip!)
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
      after { File.delete(zip_path) }

      it 'does not raise an error' do
        expect { job.create_zip! }.not_to raise_error
        expect(File).to exist(zip_path)
      end
    end

    context 'fails to zip the binary' do
      before { allow(job).to receive(:zip_command).and_return(zip_command) }

      context 'when inpath is incorrect' do
        let(:zip_command) { "zip -vr0X -s 10g #{zip_path} /wrong/path" }

        it 'raises error' do
          expect { job.create_zip! }.to raise_error(RuntimeError, /zipmaker failure/)
        end
      end

      context 'when options are unsupported' do
        let(:zip_command) { "zip -a #{zip_path} #{moab_version_path}" }

        it 'raises error' do
          expect { job.create_zip! }.to raise_error(RuntimeError, /zipmaker failure/)
        end
      end

      context 'if the utility "moved"' do
        let(:zip_command) { "zap -vr0X -s 10g #{zip_path} #{moab_version_path}" }

        it 'raises error' do
          expect { job.create_zip! }.to raise_error(Errno::ENOENT, /No such file/)
        end
      end
    end
  end
end
