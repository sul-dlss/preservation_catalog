require_relative '../../../lib/audit/catalog_to_moab_existence.rb'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe CatalogToMoabExistence do
  include_context 'fixture moabs in db'
  describe '.whole_db' do
    # NOTE: this is at the chicken scratches stage
    #  step 1: ensure load_fixtures_helper works
    it 'test_of_load_fixtures_helper (eventually will be testing code for .whole_db)' do
      described_class.whole_db
    end
  end
end
