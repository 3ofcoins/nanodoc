# Nanodoc

Generate source code documentation using Nanoc, Rocco, and
Pygments.

> *WARNING:* This is pre-alpha and I'd be surprised if it worked for
> anybody besides myself. Actually, it doesn't even fully work for me
> yet.

## Installation

Add this line to your application's Gemfile:

    gem 'nanodoc'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nanodoc

## Usage

1. Run `nanodoc` or `bundle exec nanodoc`
2. Browse the generated `dir/` directory

### Configuration

Nanodoc looks for a config file in following locations:

 - `./.nanodoc.yaml`
 - `./.nanodoc.yml`
 - `./nanodoc.yaml`
 - `./nanodoc.yml`
 - `./config/nanodoc.yaml`
 - `./config/nanodoc.yml`

This file can contain any settings [Nanoc](http://nanoc.ws/) accepts,
and some of its own settings. Important ones are:

 - `source_dir` (defaults to `'.'`)
 - `output_dir` (defaults to `public'`)
 - `project_name` (defaults to basename of the source directory)
 - `ignore` - a list of `fnmatch` expressions to ignore (defaults to
   empty list).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
