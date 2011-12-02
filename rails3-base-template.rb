git :init
git :add => "."
git :rm => "config/database.yml --cached"
git :commit => "-m 'Initial commit'"

puts "Ignoring vim temp files"
append_file ".gitignore", "*.swp\n"
git :commit => "-am 'Ignore vim temporary files'"

puts "Ignoring database config file"
append_file ".gitignore", "config/database.yml\n"
git :commit => "-am 'Ignore database config file'"

puts "Installing test gems"
inject_into_file "Gemfile", :after => "gem 'pg'\n" do
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
git :commit => "-am 'Installed test gems'"

puts "Installing haml and compass"
inject_into_file "Gemfile", :after => "gem 'pg'\n" do
<<-HAML_COMPASS_GEMS
gem 'haml'
gem 'haml-rails'
gem 'compass', '0.12.alpha.2'
HAML_COMPASS_GEMS
end

run "bundle install"

git :add => "."
git :commit => "-am 'Installed haml and compass'"
git :add => "."
git :commit => "-m 'Compass installed'"

remove_file "app/views/layouts/application.html.erb"
create_file "app/views/layouts/application.html.haml", <<-APP_LAYOUT
!!!
%html
  %head
    %title BaseApp
    = stylesheet_link_tag "application"
    = javascript_include_tag "application"
    = csrf_meta_tag
  %body.bp.two-col
    #container
      #header
        Header
      #sidebar
        Sidebar
      #content
        Content
        = notice
        = alert
        = yield
      #footer
        Footer
APP_LAYOUT

create_file "app/assets/stylesheets/layout.css.scss", <<-LAYOUT_CSS
@import "blueprint/reset";

$blueprint-grid-columns: 24;
$blueprint-container-size: 950px;
$blueprint-grid-margin: 10px;

$blueprint-grid-width: ($blueprint-container-size + $blueprint-grid-margin) / $blueprint-grid-columns - $blueprint-grid-margin;

@import "blueprint";
@import "blueprint/scaffolding";
@import "blueprint/typography";
@import "blueprint/utilities";
@import "blueprint/debug";
@import "blueprint/interaction";

body.bp {
  @include blueprint-typography(true);
  @include blueprint-utilities;
  @include blueprint-debug;
  @include blueprint-interaction;
  // Remove the scaffolding when you're ready to start doing visual design.
  // Or leave it in if you're happy with how blueprint looks out-of-the-box
  @include blueprint-scaffolding; }

body.two-col {
  #container {
    @include container;
  }
  #header, #footer {
    @include column($blueprint-grid-columns);
  }
  #sidebar {
    // One sixth of the grid columns, rounding down. With 24 cols, this is 4.
    $sidebar-columns: floor($blueprint-grid-columns / 6);
    @include column($sidebar-columns);
  }
  #content {
    // Five sixths of the grid columns, rounding up.
    // With 24 cols, this is 20.
    $content-columns: ceil(5 * $blueprint-grid-columns / 6);
    // true means it's the last column in the row
    @include column($content-columns, true);
  }
}
LAYOUT_CSS

git :commit => "-am 'Created application layout using compass'"

generate :model, "Subdomain name:string"

inject_into_class "app/models/subdomain.rb", "Subdomain", <<-SUBDOMAIN
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false
SUBDOMAIN

git :add => "."
git :commit => "-am 'Created subdomain model'"

inject_into_file "app/controllers/application_controller.rb", :after => "protect_from_forgery\n" do
<<-CURR_SUB
  helper_method :current_subdomain
  before_filter :current_subdomain

  def current_subdomain
    if request.subdomains.first.present? && request.subdomains.first != "www"
      current_subdomain = Subdomain.find_by_name(request.subdomains.first)
    else
      current_subdomain = nil
    end
    return current_subdomain
  end
CURR_SUB
end

git :commit => "-am 'Implemented current subdomain helper'"

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
    return false if request.subdomain.present? == false
    return false if request.subdomain == "www"
    Subdomain.exists?(:name => request.subdomain)
  end
end
EXTRAS

git :add => "."
git :commit => "-am 'Added subdomain routing constraints'"

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
git :commit => "-am 'Created home and sites page'"

inject_into_file "config/routes.rb", "  root :to => 'home#index'\n\n", :after => "'sites#index'\n  end\n\n"

remove_file "public/index.html"

git :commit => "-am 'Configure root page'"

# Add devise for authentication
puts "Installing devise"
inject_into_file "Gemfile", :after => "gem 'compass', '0.12.alpha.2'\n" do
<<-DEVISE_GEM
gem 'devise'
DEVISE_GEM
end

run "bundle install"
run "rails generate devise:install"
git :add => "."
git :commit => "-am 'Installed devise'"

run "rails generate devise User"
run "rails generate migration AddSubdomainToUsers subdomain_id:integer"

inject_into_file "app/models/subdomain.rb", :before => "end" do
  "  has_many :users\n"
end

inject_into_file "app/models/user.rb", :before => "end" do
<<-USER
  belongs_to :subdomain
  validates_presence_of :subdomain

  def self.find_for_authentication(conditions={})
    # Replace :subdomain with :subdomain_id in conditions hash
    subdomain = Subdomain.find_by_name conditions[:subdomain]
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
git :commit => "-am 'Added subdomain to users'"

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
git :commit => "-am 'Created subdomain tests'"
