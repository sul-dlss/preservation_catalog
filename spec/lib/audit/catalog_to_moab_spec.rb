require_relative '../../../lib/audit/catalog_to_moab.rb'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe CatalogToMoab do
  include_context 'fixture moabs in db'
  describe '.check_existence_on_dir' do
    # NOTE: this is at the chicken scratches stage
    #  step 1: ensure load_fixtures_helper works
    it 'test_of_load_fixtures_helper (eventually will be testing code for .check_existence_on_dir)' do
      described_class.check_existence_on_dir
    end
  end
end
