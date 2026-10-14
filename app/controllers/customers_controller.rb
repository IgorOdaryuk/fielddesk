class CustomersController < ApplicationController
  before_action :set_customer, only: %i[ show edit update destroy ]

  def index
    authorize Customer
    scope = policy_scope(Customer).search(params[:q]).alphabetical
    @pagy, @customers = pagy(:offset, scope.includes(:properties), limit: 25)
  end

  def show
    @jobs = @customer.jobs.includes(:technician, :property).newest_first
  end

  def new
    @customer = authorize Customer.new
    @customer.properties.build
  end

  def create
    @customer = authorize Customer.new(customer_params)

    if @customer.save
      redirect_to @customer, notice: "Customer added."
    else
      @customer.properties.build if @customer.properties.empty?
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params.except(:properties_attributes))
      redirect_to @customer, notice: "Customer updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @customer.destroy!
    redirect_to customers_path, notice: "Customer deleted.", status: :see_other
  end

  private
    def set_customer
      @customer = authorize Customer.find(params[:id])
    end

    def customer_params
      params.expect(customer: [ :name, :phone, :email, :source, :notes,
                                properties_attributes: [ [ :street, :unit, :city, :state, :zip, :access_notes ] ] ])
    end
end
