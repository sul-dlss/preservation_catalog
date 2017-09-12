Rails.application.routes.draw do
  get 'moab_storage/index'

  get 'moab_storage/show/:id', to: 'moab_storage#show'

  post 'catalog/add_preserved_object', to: 'catalog#add_preserved_object'
  patch 'catalog/update_preserved_object', to: 'catalog#update_preserved_object'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
