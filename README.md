## Installation

- Install latest Ruby version (read official [docs](https://www.ruby-lang.org/en/downloads/)).
- Install `bundler` gem

`$ gem install bundler --no-document`

- Download the repo.
- From project folder run

`$ bundle install`

It will install all dependencies

- Make sure that connection to Oracle DB can be established. Run

`$ sequel oracle://username:password@host:port/service`

If everything is fine the output should be

`Your database is stored in DB...`

- Create config file `.env` by copying `.env.sample` and replace keys with correct values.

## Usage

To ensure that the script will load correct dependencies versions run it using bundler

`$ bundle exec script.rb`

By default it will run script with ERROR log level and in list mode.

To specify log level use `-l` option

`$ bundle exec script.rb -l DEBUG`

Read more about Ruby Logger at [documentation](http://ruby-doc.org/stdlib-2.3.0/libdoc/logger/rdoc/Logger.html).

To specify script mode use `-m` option

`$ bundle exec script.rb -m details`

You can combine options

`$ bundle exec script.rb -m details -l DEBUG`

To get help

`$ bundle exec script.rb --help`
