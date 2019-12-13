# frozen_string_literal: true

require 'resque/server'

Rails.application.routes.draw do
  mount Resque::Server.new,
        at: '/resque',
        constraints: ->(req) { Settings.resque_dashboard_hostnames.include?(req.host) }

  scope 'v1' do
    resources :catalog, param: :druid, only: %i[create update]

    resources :objects, only: %i[show] do
      member do
        get 'checksum'
        get 'file', format: false # no need to add extension to url
        post 'content_diff'
      end
      collection do
        match 'checksums', via: %i[get post]
      end
    end
  end

  # TODO: Remove these when all clients are using the version-scoped routes above
  post '/catalog', to: redirect('/v1/catalog')
  match '/catalog/:druid', to: redirect('/v1/catalog/%{druid}'), via: %i[patch put]
  get '/objects/:id/checksum', to: redirect('/v1/objects/%{id}/checksum')
  get '/objects/:id/file', to: redirect('/v1/objects/%{id}/file')
  post '/objects/:id/content_diff', to: redirect('/v1/objects/%{id}/content_diff')
  match '/objects/checksums', to: redirect('/v1/objects/checksums'), via: %i[get post]
  get '/objects/:id', to: redirect('/v1/objects/%{id}')
end
