require 'rails_helper'

RSpec.describe PreservedObject, :type => :model do
	
	let!(:preserved_object) { PreservedObject.create(druid: 'ab123cd45678', version: 1, preservation_policy: 'keepit', size: 1)}
	
	it 'is not valid without valid attribute' do
		expect(PreservedObject.new).to_not be_valid
	end
	it 'is valid with valid attribute' do
		expect(preserved_object).to be_valid
	end

	it 'enforces unique constraint on druid' do 
		expect{PreservedObject.create!(druid: 'ab123cd45678')}.to raise_error(ActiveRecord::RecordInvalid)
	end

	it { should have_many(:preservation_copies) }
    it { should have_db_index(:druid) }
    it { should have_db_index(:preservation_policy) }


	
end