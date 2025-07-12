class Api::Users::OrdersController < ApplicationController
  # @openapi GET /api/users/{user_id}/orders
  # @openapi summary: Get user orders
  # @openapi description: Retrieve all orders for a specific user
  # @openapi parameters:
  #   - name: user_id
  #     in: path
  #     required: true
  #     schema:
  #       type: integer
  # @openapi responses:
  #   200:
  #     description: List of user orders
  def index
    # Mock data for testing without database
    @orders = [
      OpenStruct.new(
        id: 1,
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
      ),
      OpenStruct.new(
        id: 2,
        order_number: 1002,
        total_amount: 8000,
        status: 'pending',
        placed_at: 1.day.ago,
        order_items: [
          OpenStruct.new(
            id: 3,
            product_id: 103,
            quantity: 1,
            unit_price: 8000,
            total_price: 8000
          )
        ],
        shipping_address: OpenStruct.new(
          id: 2,
          street: '456 Oak Ave',
          city: 'Osaka',
          state: 'Osaka',
          zip_code: '530-0001',
          country: 'Japan'
        ),
        payment_method: OpenStruct.new(
          id: 2,
          type: 'credit_card',
          brand: 'mastercard',
          last4: '5678',
          expiry: '06/26',
          holder_name: 'Jane Smith',
          provider: 'stripe'
        )
      )
    ]
  end
end