require 'json'
require 'optparse'
require 'bundler'
require 'pathname'
require 'set'

module Srclib
  class Scan
    def self.summary
      "discover Ruby gems/apps in a dir tree"
    end

    def option_parser
      OptionParser.new do |opts|
        opts.banner = "Usage: scan [options]"
        opts.on("--repo URI", "URI of repository") do |v|
          @opt[:repo] = v
        end
        opts.on("--subdir DIR", "path of current dir relative to repo root") do |v|
          @opt[:repo_subdir] = v
        end
      end
    end

    def run(args)
      if Gem.win_platform?
        opt_args = []
        args.map do |arg|
          opt_args << arg.sub(/^\//, '--')
        end
        args = opt_args
      end
      option_parser.order!(args)
      raise "no args may be specified to scan (got #{args.inspect}); it only scans the current directory" if args.length != 0

      pre_wd = Pathname.pwd

      # Keep track of already discovered files in a set
      discovered_files = Set.new

      source_units = find_gems('.').map do |gemspec, gem|
        Dir.chdir(File.dirname(gemspec))
        deps = gem[:dependencies] || []
        if File.exist?("Gemfile")
          deps.concat(Bundler.definition.dependencies)
        end
        #dont add dep if gemspec name is in gemfile deps (duplicate)
        deps = deps.map{|dep| [dep.name, dep.requirement.to_s] if dep_is_valid(dep)}.compact
        gem_dir = Pathname.new(gemspec).relative_path_from(pre_wd).parent

        gem.delete(:date)

        # Add set of all now accounted for files, using absolute paths
        discovered_files.merge(gem[:files].sort.map { |x| File.expand_path(x) } )

        {
          'Name' => gem[:name],
          'Type' => 'rubygem',
          'Dir' => gem_dir,
          'Licenses' => gem[:licenses],
          'License' => gem[:license],
          'Files' => gem[:files].sort.map { |f| gem_dir == "." ? f : File.join(gem_dir, f) },
          'Dependencies' => (deps and deps.sort),
          'Data' => gem,
          'Ops' => {'depresolve' => nil, 'graph' => nil},
        }
      end

      # Ignore standard library
      if @opt[:repo] != "github.com/ruby/ruby"
        Dir.chdir(pre_wd) # Reset working directory to initial root
        scripts = find_scripts('.', source_units).map do |script_path|
          Pathname.new(script_path).relative_path_from(pre_wd)
        end

        # Filter out scripts that are already accounted for in the existing Source Units
        scripts = scripts.select do |script_file|
          script_absolute = File.expand_path(script_file)
          member = discovered_files.member? script_absolute
          !member
        end
        scripts.sort! # For testing consistency

        # If scripts were found, append to the list of source units
        if scripts.length > 0
          if File.exist?("Gemfile")
            deps = Bundler.definition.dependencies.map{|dep| [dep.name, dep.requirement.to_s] if dep_is_valid(dep)}.compact
          end

          source_units << {
            'Name' => '.',
            'Type' => 'ruby',
            'Dir' => '.',
            'Files' => scripts,
            'Dependencies' => (deps and deps.sort),
            'Data' => {
              'name' => 'rubyscripts',
              'files' => scripts,
            },
            'Ops' => {'depresolve' => nil, 'graph' => nil},
          }
        end
      end

      puts JSON.generate(source_units.sort_by { |a| a['Name'] })
    end

    def initialize
      @opt = {}
    end

    private

    # Finds all scripts that are not accounted for in the existing set of found gems
    # @param dir [String] The directory in which to search for scripts
    # @param gem_units [Array] The source units that have already been found.
    def find_scripts(dir, gem_units)
      scripts = []

      dir = File.expand_path(dir)
      Dir.glob(File.join(dir, "**/*.rb")).reject{|f| f["/spec/"] || f["/specs/"] || f["/test/"] || f["/tests/"]}.map do |script_file|
        scripts << script_file
      end

      scripts
    end

    def find_gems(dir)
      dir = File.expand_path(dir)
      gemspecs = {}
      spec_files = Dir.glob(File.join(dir, "**/*.gemspec")).reject{|f| f["/spec/"] || f["/specs/"] || f["/test/"] || f["/tests/"]}.sort
      spec_files.each do |spec_file|
        Dir.chdir(File.expand_path(File.dirname(spec_file), dir))
        spec = Gem::Specification.load(spec_file)
        if spec
          spec.normalize
          o = {}
          spec.class.attribute_names.find_all do |name|
            v = spec.instance_variable_get("@#{name}")
            o[name] = v if v
          end
          if o[:files]
            o[:files].sort!
          end
          if o[:metadata] && o[:metadata].empty?
            o.delete(:metadata)
          end
          o.delete(:rubygems_version)
          o.delete(:specification_version)
          gemspecs[spec_file] = o
        end
      end
      gemspecs
    end

    # for gemspec, type is either :development or :runtime
    # for Gemfile, groups are usually :test or :development
    def dep_is_valid(dep)
      is_dev_type = dep.type == "development"
      is_dev_group = false
      if dep.groups
        is_dev_group = (dep.groups.include?(:development) || dep.groups.include?(:test))
      end

      return (!is_dev_group && !is_dev_type)
    end
  end
end
