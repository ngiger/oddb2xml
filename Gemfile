source 'https://rubygems.org'

gemspec

group :debugger do
  gem 'vcr'
	if RUBY_VERSION.match(/^1/)
		gem 'pry-debugger'
	else
		gem 'pry-byebug'
	end
end
