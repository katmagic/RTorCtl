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
	require 'tests/exit_policy_test'
end
test.comment = "Run all of the tests."

mkdoc = task :mkdoc do
	require 'fileutils'

	alias :old_system :system
	def system(str)
		old_system(str) or raise "executing '#{str}' failed"
	end

	# Find which version we're generating our documentation from, and don't do
	# anything if it's the same as the last version.
	doc_version = `git log -n 1 --format="%h" -- lib/ README.md`.strip()
	/^Generate documentation from ([a-f0-9]+)\.$/ =~
		`git log -n 1 --format="%s" --grep='Generate documentation from ' gh-pages`
	if doc_version == $1
		puts "Our documentation hasn't changed. Exiting."
		exit
	end

	# Store any changes we might have made to the index.
	local_changes = `git status --porcelain` != ""
	system "git stash save" if local_changes

	# Generate documentation.
	FileUtils.rm_rf("doc") # Remove any old documentation we might have.
	output_dir = ".tmpdir_#{rand(10**10)}"
	system "yardoc lib -o #{output_dir}"

	# Commit the documentation to gh-pages.
	system "git checkout gh-pages"
	FileUtils.rm_rf("doc")
	File.rename(output_dir, "doc")
	system "git add doc"
	system "git commit -m 'Generate documentation from #{doc_version}.'"

	# Restore our stored changes.
	system "git checkout master"
	system "git stash pop" if local_changes
end
mkdoc.comment = "Generate documentation."
mkdoc.add_description <<END
Generate documentation and check it in to the gh-pages branch.
END

gem = task :gem do |t|
  require 'rubygems'

	spec = Gem::Specification.new do |s|
		s.author = 'katmagic'
		s.email = 'the.magical.kat@gmail.com'
		s.homepage = 'https://github.com/katmagic'
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
		s.add_development_dependency('yard')
		s.dependencies = ['only_once', 'highline', 'ip_address']
		s.requirements += ['Tor', 'Git']

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
