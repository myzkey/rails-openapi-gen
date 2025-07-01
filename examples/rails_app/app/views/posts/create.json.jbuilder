=begin
  @openapi_operation
    summary:"Create new post"
    tags:[Posts,Write] description:"Create a new blog post"
    response_description:"Created post with ID and status"
=end

# @openapi success:boolean required:true description:"Operation success status"
json.success true

# @openapi message:string required:true description:"Success message"
json.message "Post created successfully"

# @openapi post_id:integer required:true description:"ID of the newly created post"
json.post_id 123

# @openapi created_at:string required:true description:"Creation timestamp"
json.created_at Time.current.iso8601