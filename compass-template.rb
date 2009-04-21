# This template installs an standalone compass project 
# inside a rails project.

# I do not use the usual way of installing compass on rails because
# I am deploying on heroku.com which has a read only file system. 
# Before deploying to heroku I precompile the sass files to css using
# the compass command line utility.
# As suggested in http://twitter.com/chriseppstein/status/1507547283

# After the rails app based in this template is generated
# go to compass dir and run compass to generate the css files

# Run compass --watch to update the css files automatically
# when changes are made to the sass files

run 'mkdir compass'

file 'compass/config.rb', <<-FILE
# Require any additional compass plugins here.
project_type = :stand_alone
#css_dir = "stylesheets"
css_dir = "../public/stylesheets/compiled"
sass_dir = "../app/stylesheets"
images_dir = "../public/images"
output_style = :compact
# To enable relative image paths using the images_url() function:
# http_images_path = :relative
http_images_path = "/images"
FILE

run 'mkdir app/stylesheets'

file 'app/stylesheets/ie.sass', <<-FILE
@import blueprint.sass

+blueprint-ie
FILE

file 'app/stylesheets/print.sass', <<-FILE
@import blueprint.sass

+blueprint-print
FILE

file 'app/stylesheets/screen.sass', <<-FILE
@import blueprint.sass
@import compass/reset.sass
@import compass/layout.sass
@import compass/utilities.sass

+blueprint-typography

#container
  +container
  
#footer
  +column(2, true)
  +prepend(16)
  :color = !quiet_color

+sticky-footer(40px, "#container", "#container_footer", "#footer")  
FILE

file 'app/views/layouts/sample_application.html.haml', <<-FILE
!!!
%html{ "xml:lang" => "en", :lang => "en", :xmlns => "http://www.w3.org/1999/xhtml" }
  %head
    %meta{ :content => "text/html;charset=UTF-8", "http-equiv" => "content-type" }
    %title
      = 'Title'
    = stylesheet_link_tag 'compiled/screen.css', :media => 'screen, projection'
    = stylesheet_link_tag 'compiled/print.css', :media => 'print'
    /[if IE]
      = stylesheet_link_tag 'compiled/ie.css', :media => 'screen, projection'

    = javascript_include_tag :defaults
  %body{body_attributes}
    #container.container
      #user_menu
      #main_menu
      = yield
      #container_footer
    #footer
      footer
FILE
