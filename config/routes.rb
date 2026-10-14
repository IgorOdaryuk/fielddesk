Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "home#show"

  resource :dashboard, only: :show
  resource :schedule, only: :show

  resources :customers do
    resources :properties, except: %i[ index show ]
  end

  resources :jobs do
    patch :transition, on: :member
    resources :notes, only: :create, controller: "job_notes"
    resources :photos, only: :create, controller: "job_photos"
  end

  namespace :my do
    resources :jobs, only: %i[ index show ]
  end

  resources :users, except: %i[ show destroy ] do
    patch :toggle_active, on: :member
  end

  resources :audit_logs, only: :index

  get "up" => "rails/health#show", as: :rails_health_check
end
