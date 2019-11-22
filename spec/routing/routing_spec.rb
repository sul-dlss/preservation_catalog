# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes', type: :routing do
  describe 'objects/:id/file' do
    it 'file_object_path' do
      druid = 'druid:ab123cd4567'
      expect(get: file_object_path(id: druid)).to route_to(controller: 'objects', action: 'file', id: druid)
    end
  end

  describe 'objects/:id/checksum' do
    it 'checksum_object_path' do
      druid = 'druid:ab123cd4567'
      expect(get: checksum_object_path(id: druid)).to route_to(controller: 'objects', action: 'checksum', id: druid)
    end
  end
end
