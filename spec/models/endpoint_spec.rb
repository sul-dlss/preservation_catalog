require 'rails_helper'

RSpec.describe Endpoint, :type => :model do

	let!(:endpoint) { Endpoint.create(endpoint_name: 'aws', endpoint_type: 'cloud') }

	it 'is not valid without valid attributes' do
		expect(Endpoint.new).to_not be_valid
	end

	it 'is valid with valid attributes' do 
		expect(endpoint).to be_valid
	end

	it 'it enforces unique constraint on endpoint_name' do 
		expect{Endpoint.create!(endpoint_name: 'aws', endpoint_type:'cloud')}.to raise_error(ActiveRecord::RecordInvalid)
	end

	it { should have_many(:preservation_copies) }
    it { should have_db_index(:endpoint_name) }
    it { should have_db_index(:endpoint_type) }



end