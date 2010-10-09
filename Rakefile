def get_latest_version
	ver = `git tag`.grep(/^v([\d\.]+)/){$1}.sort(){ |a,b|
		f = Proc.new{|z| z.split(".").reduce(0){|x,y| x * 256**2 + y}}
		f[a] <=> f[b]
	}[-1] || "0.0.0"
end

def get_revision_id
	"%09d" % `git log -n1 --pretty="format:%h"`.strip().to_i(16)
end

test = task :test do
	$LOAD_PATH.unshift( "lib" )

	require 'test/unit'
	require 'tests/getinfo'
	require 'tests/exit_policy'
	require 'tests/parse_response'
	require 'tests/quote'
	require 'tests/relay'
end
test.comment = "Run all of the tests."

mkdoc = task :mkdoc do
	system "asciidoc README.asciidoc"
end
mkdoc.comment = "Generate documentation."
mkdoc.add_description <<EOT
Make README.html from README.asciidoc. asciidoc must be be installed for this to
work.
EOT

gem = task :gem do |t|
  require 'rubygems'

	spec = Gem::Specification.new do |s|
		s.author = 'katmagic'
		s.email = 'the.magical.kat@gmail.com'
		s.homepage = 'http://github.com/katmagic'
		s.rubyforge_project = 'rtorctl'

		s.name = 'rtorctl'
		s.summary = 'RTorCtl is a Rubyonic Tor controller.'
		s.description = <<END
RTorCtl is a highly magical Rubyonic Tor controller. It aims to present a clean,
simple, and highly polished interface. It uses a lot of lazy evaluation and
other things behind the curtain.
END
		s.license = 'Public Domain'
		s.version = "#{get_latest_version()}.#{get_revision_id()}"
		s.platform = Gem::Platform::CURRENT
		s.required_ruby_version = ">= #{VERSION}"
		s.add_development_dependency('rake')
		s.requirements << 'Tor'

		s.files = FileList["lib/**", "tests/**", "UNLICENSE", "README.asciidoc"]
		s.test_files = FileList["tests/**"]

		if ENV['GEM_SIG_KEY']
			s.signing_key = ENV['GEM_SIG_KEY']
			s.cert_chain = ENV['GEM_CERT_CHAIN'].split(",") if ENV['GEM_CERT_CHAIN']
		else
			warn "environment variable $GEM_SIG_KEY unspecified; not signing gem"
		end
	end

	puts Gem::Builder.new(spec).build()
end
gem.comment = "Create a Ruby gem."
gem.add_description <<EOT
Create a Ruby gem. If the environment variable GEM_SIG_KEY is set, sign the gem
with the certificate at its location. Additionally, if the environment variable
GEM_CERT_CHAIN is set, use the comma-seperated list of certificates as the gem's
certificate chain. (See the documentation for Gem::Specification.cert_chain=().)
EOT
