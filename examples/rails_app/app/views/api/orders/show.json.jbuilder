# @openapi order:object
json.id order.id
# @openapi order_number:integer
json.order_number order.order_number
# @openapi total_amount:integer
json.total_amount order.total_amount
# @openapi status:string
json.status order.status
# @openapi placed_at:string
json.placed_at order.placed_at.iso8601

# @openapi order_items:array
json.order_items do
  json.array! order.order_items do |item|
    json.partial! partial: 'api/orders/model/order_item',
                  locals: { order_item: item }
  end
end

# @openapi shipping_address:object
json.shipping_address do
  json.partial! partial: 'api/users/model/address',
                locals: { address: order.shipping_address }
end

# @openapi payment_method:object
json.payment_method do
  json.partial! partial: 'api/orders/model/payment_method',
                locals: { payment_method: order.payment_method }
end