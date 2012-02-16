git :init
git :add => "."
git :rm => "config/database.yml --cached"
git :commit => "-m 'Initial commit'"

puts "Ignoring vim temp files"
append_file ".gitignore", "*.swp\n"
git :add => "."
git :commit => "-am 'Ignore vim temporary files'"

puts "Ignoring database config file"
append_file ".gitignore", "config/database.yml\n"
git :add => "."
git :commit => "-am 'Ignore database config file'"

puts "Installing test gems"
inject_into_file "Gemfile", :after => "gem 'sqlite3'\n" do
<<-TEST_GEMS

group :development, :test do
  gem 'rspec'
  gem 'rspec-rails'
  gem 'cucumber'
  gem 'cucumber-rails'
  gem 'capybara'
  gem 'launchy'
  gem 'database_cleaner'
end
TEST_GEMS
end

run "bundle install"

generate "rspec:install"
generate "cucumber:install --capybara"

git :add => "."
git :commit => "-am 'Install test gems'"

puts "Installing haml"
inject_into_file "Gemfile", :after => "gem 'sqlite3'\n" do
<<-HAML_GEMS
gem 'haml'
gem 'haml-rails'
HAML_GEMS
end

run "bundle install"

git :add => "."
git :commit => "-am 'Install haml'"

puts "Installing twitter bootstrap"
inject_into_file "Gemfile", :after => "gem 'sass-rails',   '~> 3.2.3'\n" do
<<-BOOTSTRAP_GEM
  gem 'bootstrap-sass', '~>2.0.0'
BOOTSTRAP_GEM
end

run "bundle install"

git :add => "."
git :commit => "-am 'Install twitter bootstrap'"

puts "Installing simple_form"
inject_into_file "Gemfile", :after => "gem 'haml-rails'\n" do
<<-SIMPLE_FORM
gem "simple_form", '2.0.0.rc'
SIMPLE_FORM
end

run "bundle install"

run "rails generate simple_form:install --bootstrap"

git :add => "."
git :commit => "-am 'Install simple form'"

remove_file "app/views/layouts/application.html.erb"
create_file "app/views/layouts/application.html.haml", <<-APP_LAYOUT
!!!
%html
  %head
    %title= content_for?(:title)? yield(:title) : "BaseApp"
    = stylesheet_link_tag "application"
    = javascript_include_tag "application"
    = csrf_meta_tag
  %body
    #container.container
      #navbar.navbar.navbar-fixed-top
        .navbar-inner
          .container
            = link_to "BaseApp", '/', :class => "brand"
            %ul.nav
              %li= link_to("Option 1")
              %li= link_to("Option 2")
              %li= link_to("Option 3")
      #content
        Content
        = notice
        = alert
        = yield
      #footer
        Footer
APP_LAYOUT

inject_into_file "app/helpers/application_helper.rb", :after => "module ApplicationHelper\n" do
<<-APP_HELPER
  def title(*parts)
    unless parts.empty?
      content_for :title do
        (parts << "BaseApp").join(" - ")
      end
    end
  end
APP_HELPER
end

create_file "app/assets/stylesheets/layout.css.scss", <<-LAYOUT_CSS
@import "bootstrap";

table {
  @extend .table;
  @extend .table-striped;
}

body {
  padding-top: 40px;
}

form {
  @extend .form-horizontal
}

LAYOUT_CSS

git :add => "."
git :commit => "-am 'Create application style'"

inject_into_file "config/application.rb", :after => "config.assets.enabled = true\n" do
<<-APP_CONFIG
    config.assets.initialize_on_precompile = false
APP_CONFIG
end

git :add => "."
git :commit => "-am 'Config to run at heroku'"

generate :model, "Subdomain name:string"

inject_into_class "app/models/subdomain.rb", "Subdomain", <<-SUBDOMAIN
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false
SUBDOMAIN

git :add => "."
git :commit => "-am 'Create subdomain model'"

inject_into_file "app/controllers/application_controller.rb", :after => "protect_from_forgery\n" do
<<-CURR_SUB
  helper_method :current_subdomain
  before_filter :current_subdomain

  def current_subdomain
    return nil if request.subdomain.present? == false
    subdomain_name = request.subdomain.split('.').first
    return nil if subdomain_name == "www"
    return Subdomain.find_by_name subdomain_name
  end
CURR_SUB
end

git :add => "."
git :commit => "-am 'Implement current subdomain helper'"

gsub_file "config/application.rb", /# config.autoload_paths/, "config.autoload_paths"

inject_into_file "config/routes.rb", :after => "::Application.routes.draw do\n" do
<<-CONSTRAINTS

  constraints(SubdomainRoute) do
    match '/' => 'sites#index'
  end

CONSTRAINTS
end

create_file "extras/subdomain_route.rb", <<-EXTRAS
class SubdomainRoute
  def self.matches?(request)
    # request.subdomain is virtus if host is virtus.mydomain.com
    # request.subdomain is virtus.mydomain id host is virtus.mydomain.com.mx
    return false if request.subdomain.present? == false
    subdomain_name = request.subdomain.split('.').first
    return false if subdomain_name == "www"
    Subdomain.exists? subdomain_name
  end
end
EXTRAS

git :add => "."
git :commit => "-am 'Add subdomain routing constraints'"

generate :controller, "home"
generate :controller, "sites"

create_file "app/views/home/index.html.haml", <<-HOME_INDEX
%h1 Home page
HOME_INDEX

create_file "app/views/sites/index.html.haml", <<-SITE_INDEX
%h1 Site page
%p= "Subdomain: \#{current_subdomain.name}" 
SITE_INDEX

git :add => "."
git :commit => "-am 'Create home and sites page'"

inject_into_file "config/routes.rb", "  root :to => 'sites#index'\n\n", :after => "'sites#index'\n  end\n\n"

remove_file "public/index.html"

git :add => "."
git :commit => "-am 'Configure root page'"

# Add devise for authentication
puts "Installing devise"
inject_into_file "Gemfile", :after => "gem 'haml-rails'\n" do
<<-DEVISE_GEM
gem 'devise'
DEVISE_GEM
end

run "bundle install"
run "rails generate devise:install"
git :add => "."
git :commit => "-am 'Install devise'"

run "rails generate devise User"
run "rails generate migration AddSubdomainToUsers subdomain_id:integer"

inject_into_file "app/models/subdomain.rb", :before => "end" do
  "  has_many :users\n"
end

inject_into_file "app/models/user.rb", :before => "end" do
<<-USER
  belongs_to :subdomain
  validates_presence_of :subdomain

  # Checks that the user belongs to the subdomain
  # The conditions received are from devise.rb
  # config.authentication_keys and config.request_keys
  # and must match column names in user table
  def self.find_for_authentication(conditions={})
    # conditions[:subdomain] is virtus if host is virtus.mydomain.com
    # conditions[:subdomain] is virtus.mydomain id host is virtus.mydomain.com.mx
    subdomain_name = conditions[:subdomain].split('.').first

    # Replace :subdomain with :subdomain_id in conditions hash
    subdomain = Subdomain.find_by_name subdomain_name
    conditions.delete(:subdomain)
    conditions[:subdomain_id] = subdomain.id
    super
  end
USER
end

inject_into_file "config/initializers/devise.rb", :after => "  # config.request_keys = []\n" do
  "  config.request_keys = [:subdomain]\n"
end

inject_into_file "app/controllers/application_controller.rb", :after => "before_filter :current_subdomain\n" do
  "  before_filter :authenticate_user!\n"
end

git :add => "."
git :commit => "-am 'Add subdomain to users'"

create_file "features/support/custom_env.rb", <<-CUSTOM_ENV
require 'cucumber/rails'

# This fix applied as shown in https://github.com/aslakhellesoy/cucumber-rails/issues/97
if RUBY_VERSION =~ /1.8/
  require 'test/unit/testresult'
  Test::Unit.run = true
end

class Capybara::Server
  def self.my_subdomain=(value)
    @@subdomain = value
  end
  def self.my_subdomain
    @@subdomain || ""
  end
  def self.my_host
    if my_subdomain == ""
      "http://example.com"
    else
      "http://\#{my_subdomain}.example.com"
    end
  end
end
CUSTOM_ENV

create_file "features/authentication.feature", <<-AUTHENTICATION_FEATURE
Feature: Authorization
  In order to use the system
  As a subdomain member
  I want to access the system

  Background:
    Given subdomain a
    And subdomain b
    And user alpha for subdomain a
    And user beta for subdomain b

  Scenario: Access forbidden to any page
    When I visit subdomain a
    And I go to the home page
    Then I should see the login page

  Scenario: Allow access to users from this subdomain
    When I visit subdomain a
    And I login as user alpha
    Then I should be allowed to enter

  Scenario: Do not allow access to users from other subdomain
    When I visit subdomain a
    And I login as user beta
    Then I should not be allowed to enter
AUTHENTICATION_FEATURE

create_file "features/step_definitions/authentication_steps.rb", <<-AUTHENTICATION_STEPS
Given /^subdomain (.+)$/ do |sub|
  Subdomain.create(:name => sub)
end

Given /^user (.+) for subdomain (.+)$/ do |user_name, subdomain_name|
  subdomain = Subdomain.find_by_name(subdomain_name)
  user = subdomain.users.new(:email => "\#{user_name}@example.com", :password => user_name * 6, :password_confirmation => user_name*6)
  user.save
end

When /^I login as user (.+)$/ do |user_name|
  step "I go to the login page"
  within("div#content") do
    fill_in 'Email',    :with => "\#{user_name}@example.com"
    fill_in 'Password', :with => user_name * 6
    click_button 'Sign in'
  end
end

Given /^I am a logged in user in a subdomain$/ do
  Given "subdomain test"
  And "user u for subdomain test"
  When "I visit subdomain test"
  And "I login as user u"
end

Then /^I should see the login page$/ do
  within("div#content") do
    assert has_content?("Email")
    assert has_content?("Password")
    assert has_content?("You need to sign in or sign up before continuing.")
  end
  # TODO We are not checking that this page is for subdomain X
end

Then /^I should be allowed to enter$/ do
  current_path = URI.parse(current_url).path
  assert_equal "/", current_path
  within("div#content") do
    assert has_content?("Signed in successfully.")
    assert has_content?(Capybara::Server.my_subdomain)
  end
end

Then /^I should not be allowed to enter$/ do
  current_path = URI.parse(current_url).path
  assert_equal new_user_session_path, current_path
  within("div#content") do
    assert has_content?("Invalid email or password.")
  end
end
AUTHENTICATION_STEPS

create_file "features/step_definitions/navigation_steps.rb", <<-NAVIGATION_STEPS
When /^I visit no subdomain$/ do
  Capybara::Server.my_subdomain = ""
end

When /^I visit subdomain (.+)$/ do |subdomain|
  Capybara::Server.my_subdomain = subdomain
end

When /^I go to the home page$/ do
  visit "\#{Capybara::Server.my_host}/"
end

When /^I go to the login page$/ do
  visit "\#{Capybara::Server.my_host}\#{new_user_session_path}"
end

Then /^show me the page$/ do
  save_and_open_page
end

NAVIGATION_STEPS

run "rm features/step_definitions/web_steps.rb"

git :add => "."
git :commit => "-am 'Create subdomain tests'"
