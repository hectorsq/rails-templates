gem 'authlogic'
rake 'gems:install', :sudo => true

# generate user_session model at app/models/user_session.rb
generate(:session, "user_session") 

# generate user_session controller
generate(:controller, "user_sessions")

# map user_sesion resources
route "map.resource :account, :controller => 'users'"
route "map.resource :user_session"
route "map.root :controller => 'user_sessions', :action => 'new'"
route "map.login  '/login',  :controller => 'user_sessions', :action => 'destroy'"

# setup UsesSessionsController
file "app/controllers/user_sessions_controller.rb", <<-FILE
class UserSessionsController < ApplicationController  
  skip_before_filter :require_user # Override application wide filter
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy

  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Login successful!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    flash[:notice] = "Logout successful!"
    redirect_back_or_default new_user_session_url
  end
end
FILE

generate(:scaffold, "user", 
  "login:string",
  "crypted_password:string",
  "password_salt:string",
  "persistence_token:string",
  "login_count:integer",
  "last_request_at:datetime",
  "last_login_at:datetime",
  "current_login_at:datetime",
  "last_login_ip:string",
  "current_login_ip:string"
)

rake "db:migrate"

# make user act as authentic
file "app/models/user.rb", <<-FILE
class User < ActiveRecord::Base
  acts_as_authentic
end
FILE

file "app/controllers/users_controller.rb", <<-FILE
class UsersController < ApplicationController
  # Comment the 3 following lines to disable new user registration
  skip_before_filter :require_user # Override application wide filter
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]

  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
    if @user.save
      flash[:notice] = "Account registered!"
      redirect_back_or_default account_url
    else
      render :action => :new
    end
  end

  def show
    @user = @current_user
  end

  def edit
    @user = @current_user
  end

  def update
    @user = @current_user # makes our views "cleaner" and more consistent
    if @user.update_attributes(params[:user])
      flash[:notice] = "Account updated!"
      redirect_to account_url
    else
      render :action => :edit
    end
  end
end
FILE

# TODO falta agregar las vistas

file "app/controllers/application_controller.rb", <<-FILE
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  before_filter :require_user # Protect the whole app by requiring a logged in user always
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.user
    end
    
    def require_user
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to account_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
end
FILE

file "app/views/users/_form.erb", <<-FILE
<%= form.label :login %><br />
<%= form.text_field :login %><br />
<br />
<%= form.label :password, form.object.new_record? ? nil : "Change password" %><br />
<%= form.password_field :password %><br />
<br />
<%= form.label :password_confirmation %><br />
<%= form.password_field :password_confirmation %><br />
FILE

file "app/views/users/edit.html.erb", <<-FILE
<h1>Edit My Account</h1>
 
<% form_for @user, :url => account_path do |f| %>
  <%= f.error_messages %>
  <%= render :partial => "form", :object => f %>
  <%= f.submit "Update" %>
<% end %>
 
<br /><%= link_to "My Profile", account_path %>
FILE

file "app/views/users/new.html.erb", <<-FILE
<h1>Register</h1>
 
<% form_for @user, :url => account_path do |f| %>
  <%= f.error_messages %>
  <%= render :partial => "form", :object => f %>
  <%= f.submit "Register" %>
<% end %>
FILE

file "app/views/users/show.html.erb", <<-FILE
<p>
  <b>Login:</b>
  <%=h @user.login %>
</p>
 
<p>
  <b>Login count:</b>
  <%=h @user.login_count %>
</p>
 
<p>
  <b>Last request at:</b>
  <%=h @user.last_request_at %>
</p>
 
<p>
  <b>Last login at:</b>
  <%=h @user.last_login_at %>
</p>
 
<p>
  <b>Current login at:</b>
  <%=h @user.current_login_at %>
</p>
 
<p>
  <b>Last login ip:</b>
  <%=h @user.last_login_ip %>
</p>
 
<p>
  <b>Current login ip:</b>
  <%=h @user.current_login_ip %>
</p>
 
 
<%= link_to 'Edit', edit_account_path %>
FILE

file "app/views/user_sessions/new.html.erb", <<-FILE
<h1>Login</h1>
 
<% form_for @user_session, :url => user_session_path do |f| %>
  <%= f.error_messages %>
  <%= f.label :login %><br />
  <%= f.text_field :login %><br />
  <br />
  <%= f.label :password %><br />
  <%= f.password_field :password %><br />
  <br />
  <%= f.check_box :remember_me %><%= f.label :remember_me %><br />
  <br />
  <%= f.submit "Login" %>
<% end %>
FILE

file "app/views/password_resets/edit.html.erb", <<-FILE
<h1>Change My Password</h1>
 
<% form_for @user, :url => password_reset_path, :method => :put do |f| %>
  <%= f.error_messages %>
  <%= f.label :password %><br />
  <%= f.password_field :password %><br />
  <br />
  <%= f.label :password_confirmation %><br />
  <%= f.password_field :password_confirmation %><br />
  <br />
  <%= f.submit "Update my password and log me in" %>
<% end %>
FILE

file "app/views/password_resets/new.html.erb", <<-FILE
<h1>Forgot Password</h1>
 
Fill out the form below and instructions to reset your password will be emailed to you:<br />
<br />
 
<% form_tag password_resets_path do %>
  <label>Email:</label><br />
  <%= text_field_tag "email" %><br />
  <br />
  <%= submit_tag "Reset my password" %>
<% end %>
FILE

file "app/views/layouts/application.html.erb", <<-FILE
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
  <title><%= controller.controller_name %>: <%= controller.action_name %></title>
  <%= stylesheet_link_tag 'scaffold' %>
  <%= javascript_include_tag :defaults %>
</head>
<body>

<span style="float: right; text-align: right;"><%= link_to "Source code", "http://github.com/binarylogic/authlogic_example" %> | <%= link_to "Setup tutorial", "http://www.binarylogic.com/2008/11/3/tutorial-authlogic-basic-setup" %> | <%= link_to "Password reset tutorial", "http://www.binarylogic.com/2008/11/16/tutorial-reset-passwords-with-authlogic" %><br />
<%= link_to "OpenID tutorial", "http://www.binarylogic.com/2008/11/21/tutorial-using-openid-with-authlogic" %> | <%= link_to "Authlogic Repo", "http://github.com/binarylogic/authlogic" %> | <%= link_to "Authlogic Doc", "http://authlogic.rubyforge.org/" %></span>
<h1>Authlogic Example App</h1>
<%= pluralize User.logged_in.count, "user" %> currently logged in<br /> <!-- This based on last_request_at, if they were active < 10 minutes they are logged in -->
<br />
<br />


<% if !current_user %>
  <%= link_to "Register", new_account_path %> |
  <%= link_to "Log In", new_user_session_path %> |
<% else %>
  <%= link_to "My Account", account_path %> |
  <%= link_to "Logout", user_session_path, :method => :delete, :confirm => "Are you sure you want to logout?" %>
<% end %>

<p style="color: green"><%= flash[:notice] %></p>

<%= yield  %>

</body>
</html>
FILE

run "rm public/index.html"
run "rm app/views/layouts/users.html.erb"

