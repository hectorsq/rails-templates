## Rails 3 base

This template creates a Rails 3 base application that manages subdomains.

Integration tests using Cucumber and Capybara
Uses twitter bootstrap

Prerequisites

You should have installed Rails 3.2.1 or above. This may seem obvious but this template
does not work with prior Rails versions.

    rails new test_app -m rails3-base-template

    cd test_app

    rake db:create

    rake db:migrate

    rake cucumber
