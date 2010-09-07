# autocomplete

An easy way to use jQuery's autocomplete with Rails 3.

## Before you start

Make sure your project is using jQuery-ui with the autocomplete widget
before you continue.

You can find more info about that here:

* http://jquery.com/
* http://jqueryui.com/demos/autocomplete/
* http://github.com/rails/jquery-ujs

I'd encourage you to understand how to use those 3 amazing tools before attempting to use this gem.

## Installing

Copy it to vendor/plugins

Run the generator

    rails generate autocomplete
    
And include autocomplete-rails.js on your layouts

    javascript_include_tag "autocomplete-rails.js"

## Usage

### Model Example

Assuming you have a Brand model:

    class Brand < ActiveRecord::Base
    end

    create_table :brand do |t|
      t.column :name, :string
    end

### Controller

To set up the required action on your controller, all you have to do is call it with the class name and the method
as in the following example:

    class ProductsController < Admin::BaseController
      autocomplete :brand, :name
    end

This will create an action _autocomplete_brand_name_ on your controller, don't forget to add it on your routes file

    resources :products do
      get :autocomplete_brand_name, :on => :collection
    end

To add an additional fields to label of the autocomplete offers, you can use:

    :add_also => [:first_name, :last_name]

This will use <email, first_name, last_name> as label, but still will use only email as a result.

By default, the search starts from the beginning of the string you're searching for. If you want to do a full search, set the _full_ parameter to true.

    class ProductsController < Admin::BaseController
      autocomplete :brand, :name, :full => true
    end

#### :full => true

The following terms would match the query 'un':

* Luna
* Unacceptable
* Rerun

#### :full => false (default behavior)

Only the following terms mould match the query 'un':

* Unacceptable

### View

On your view, all you have to do is include the attribute autocomplete on the text field
using the url to the autocomplete action as the value.
    form_for @product do |f|
      f.text_field :brand_name, :autocomplete => autocomplete_brand_name_products_path
    end

This will generate an HTML tag that looks like:

    <input type="text" autocomplete="products/autocomplete_brand_name">

Now your autocomplete JS code is unobtrusive, Rails 3 style.
