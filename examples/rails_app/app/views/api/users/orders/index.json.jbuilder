# @openapi orders:array
json.array! @orders do |order|
  json.partial! partial: 'api/users/model/order',
                locals: { order: order }
end