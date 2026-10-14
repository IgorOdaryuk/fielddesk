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
    patch :reschedule, on: :member
    resources :notes, only: :create, controller: "job_notes"
    resources :photos, only: :create, controller: "job_photos"
    resource :invoice, only: :create
  end

  resources :invoices, only: %i[ index show update ] do
    member do
      post :send_invoice
      post :void
    end
    resources :items, only: %i[ create destroy ], controller: "invoice_items"
    resources :payments, only: :create
  end

  resources :outbound_messages, only: :index, path: "outbox"

  # Public, token-protected payment page for customers.
  scope "pay/:token", controller: :pay do
    get "/", action: :show, as: :pay
    post "start", action: :start, as: :pay_start
    get "checkout", action: :checkout, as: :pay_checkout
    post "checkout", action: :charge
  end

  post "webhooks/stripe", to: "stripe_webhooks#create"

  namespace :my do
    resources :jobs, only: %i[ index show ]
  end

  resources :users, except: %i[ show destroy ] do
    patch :toggle_active, on: :member
  end

  resources :audit_logs, only: :index

  get "up" => "rails/health#show", as: :rails_health_check
end
