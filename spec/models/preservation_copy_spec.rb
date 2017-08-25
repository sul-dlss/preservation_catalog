require 'rails_helper'

RSpec.describe PreservationCopy, :type => :model do
	let!(:preservation_object2){PreservedObject.create!(druid: 'ab123cd45679', version: 1, preservation_policy: 'keepit', size: 1)}
	let!(:endpoint2){Endpoint.create!(endpoint_name: 'oracle', endpoint_type: 'cloud')}
	let!(:preservation_copy){PreservationCopy.create!(preserved_object_id: preservation_object2.id, endpoint_id: endpoint2.id, version: 0, status: 'fixity_error')}

	it 'is not valid without valid attributes' do
		expect(PreservationCopy.new).to_not be_valid
	end

	it 'is valid with valid attributes' do 
		expect(preservation_copy).to be_valid
	end
    
    it { should belong_to(:endpoint) }
    it { should belong_to(:preserved_object) }
    it { should have_db_index(:last_audited) }
    it { should have_db_index(:endpoint_id) }
    it { should have_db_index(:preserved_object_id) }




end