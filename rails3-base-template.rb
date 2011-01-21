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
gem "rspec", :group => :test
gem "rspec-rails", :group => :test
gem "cucumber", :group => :test
gem "cucumber-rails", :group => :test
gem "capybara", "0.3.9", :group => :test
gem "rspec", :group => :development
gem "rspec-rails", :group => :development
gem "cucumber", :group => :development
gem "cucumber-rails", :group => :development
gem "capybara", "0.3.9", :group => :development

run "bundle install"

generate "rspec:install"
generate "cucumber:install --capybara"

git :add => "."
git :commit => "-am 'Installed test gems'"

puts "Installing haml and compass"
gem "haml"
gem "haml-rails"
gem "compass"

run "bundle install"

run "compass init rails --using blueprint/semantic --sass-dir app/stylesheets --css-dir public/stylesheets/compiled"

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
    = stylesheet_link_tag :all
    = javascript_include_tag :defaults
    = csrf_meta_tag
    = stylesheet_link_tag 'compiled/screen.css', :media => 'screen, projection'
    = stylesheet_link_tag 'compiled/print.css', :media => 'print'
    /[if lt IE 8]
      = stylesheet_link_tag 'compiled/ie.css', :media => 'screen, projection'
    = stylesheet_link_tag 'compiled/application.css', :media => 'screen, projection'
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

run "touch app/stylesheets/application.scss"

git :commit => "-am 'Created application layout using compass'"

gsub_file "app/stylesheets/partials/_two_col.scss", /third/, "sixth" 
gsub_file "app/stylesheets/partials/_two_col.scss", /this is 8/, "this is 4" 
gsub_file "app/stylesheets/partials/_two_col.scss", /Two sixths/, "Five sixths" 
gsub_file "app/stylesheets/partials/_two_col.scss", /this is 16/, "this is 20" 
gsub_file "app/stylesheets/partials/_two_col.scss", /blueprint-grid-columns \/ 3/, "blueprint-grid-columns / 6" 
gsub_file "app/stylesheets/partials/_two_col.scss", /2 \* blueprint-grid-columns/, "5 * blueprint-grid-columns"

git :commit => "-am 'Adjusted sidebar to 1/6 and content to 5/6'"

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

create_file "features/subdomains.feature", <<-SUBDOMAINS_FEATURE
Feature:

  Scenario: Visit no subdomain
    When I visit no subdomain
    And I go to the home page
    Then I should see "Home page"

  Scenario: Visit main subdomain
    When I visit subdomain "www"
    And I go to the home page
    Then I should see "Home page"

  Scenario: Visit non existing subdomain
    When I visit subdomain "s1"
    And I go to the home page
    Then I should see "Home page"

  Scenario: Visit existing subdomain
    Given subdomain "s1"
    When I visit subdomain "s1"
    And I go to the home page
    Then I should see "Site page"
    And I should see "Subdomain: s1"

  Scenario: Visit several subdomains
    Given subdomain "s1"
    And subdomain "s2"
    When I visit subdomain "s1"
    And I go to the home page
    Then I should see "Site page"
    And I should see "Subdomain: s1"
    # The following does not work because it seems that capybara
    # cannot change the host on the fly
    # When I visit subdomain "s2"
    # And I go to the home page
    # Then I should see "Site page"
    # And I should see "Subdomain: s2"
SUBDOMAINS_FEATURE

create_file "features/step_definitions/subdomain_steps.rb", <<-SUBDOMAINS_STEPS
Given /^subdomain "([^"]*)"$/ do |sub|
  Subdomain.create(:name => sub)
end

# 
# This is not the right way to test subdomains, furthermore it does not work with capybara > 0.3.9, please read
# http://groups.google.com/group/ruby-capybara/browse_thread/thread/f6a109ec6d254bc8/9c39ccf587af9700?lnk=gst&q=subdomain#9c39ccf587af9700
# However I have not figured yet another way to test subdomains, I am still investigating :(
#
When /^I visit no subdomain$/ do
  Capybara.default_host = "example.com" #for Rack::Test
  Capybara.app_host = "http://example.com:9887" if Capybara.current_driver == :culerity
end

When /^I visit subdomain "([^"]*)"$/ do |sub|
  Capybara.default_host = "\#{sub}.example.com" #for Rack::Test
  Capybara.app_host = "http://\#{sub}.example.com:9887" if Capybara.current_driver == :culerity
end
SUBDOMAINS_STEPS

git :add => "."
git :commit => "-am 'Created subdomain tests'"

