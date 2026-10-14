class PropertiesController < ApplicationController
  before_action :set_customer
  before_action :set_property, only: %i[ edit update destroy ]

  def new
    @property = authorize @customer.properties.build
  end

  def create
    @property = authorize @customer.properties.build(property_params)

    if @property.save
      redirect_to @customer, notice: "Address added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @property.update(property_params)
      redirect_to @customer, notice: "Address updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @property.destroy!
    redirect_to @customer, notice: "Address removed.", status: :see_other
  end

  private
    def set_customer
      @customer = Customer.find(params[:customer_id])
    end

    def set_property
      @property = authorize @customer.properties.find(params[:id])
    end

    def property_params
      params.expect(property: [ :street, :unit, :city, :state, :zip, :access_notes ])
    end
end
