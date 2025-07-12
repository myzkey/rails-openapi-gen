class Api::OrdersController < ApplicationController
  def show
    # Mock data for testing without database
    @order = OpenStruct.new(
      id: params[:id].to_i,
      order_number: 1001,
      total_amount: 15000,
      status: 'completed',
      placed_at: Time.current,
      order_items: [
        OpenStruct.new(
          id: 1,
          product_id: 101,
          quantity: 2,
          unit_price: 5000,
          total_price: 10000
        ),
        OpenStruct.new(
          id: 2,
          product_id: 102,
          quantity: 1,
          unit_price: 5000,
          total_price: 5000
        )
      ],
      shipping_address: OpenStruct.new(
        id: 1,
        street: '123 Main St',
        city: 'Tokyo',
        state: 'Tokyo',
        zip_code: '100-0001',
        country: 'Japan'
      ),
      payment_method: OpenStruct.new(
        id: 1,
        type: 'credit_card',
        brand: 'visa',
        last4: '1234',
        expiry: '12/25',
        holder_name: 'John Doe',
        provider: 'stripe'
      )
    )
  end
end