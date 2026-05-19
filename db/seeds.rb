if Doorkeeper::Application.count.zero?
  Doorkeeper::Application.create(name: "Facebook-API", redirect_uri: "", scopes: "")
end
