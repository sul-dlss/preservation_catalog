# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes', type: :routing do
  let(:id) { 'druid:ab123cd4567' }

  describe 'objects/:id' do
    it 'object_path' do
      expect(get: object_path(id: id)).to route_to(controller: 'objects', action: 'show', id: id)
    end
  end

  describe 'objects/:id/file' do
    it 'file_object_path' do
      expect(get: file_object_path(id: id)).to route_to(controller: 'objects', action: 'file', id: id)
    end
  end

  describe 'objects/:id/checksum' do
    it 'checksum_object_path' do
      expect(get: checksum_object_path(id: id)).to route_to(controller: 'objects', action: 'checksum', id: id)
    end
  end

  describe 'objects/checksums' do
    it 'GET checksums_objects_path' do
      expect(get: checksums_objects_path).to route_to(controller: 'objects', action: 'checksums')
    end

    it 'POST checksums_objects_path' do
      expect(post: checksums_objects_path).to route_to(controller: 'objects', action: 'checksums')
    end
  end

  describe 'objects/:id/content_diff' do
    it 'content_diff_object_path' do
      expect(post: content_diff_object_path(id: id)).to route_to(controller: 'objects', action: 'content_diff', id: id)
    end
  end
end
