Rails.application.routes.draw do
  get 'moab_storage/index'

  get 'moab_storage/show/:id', to: 'moab_storage#show'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
