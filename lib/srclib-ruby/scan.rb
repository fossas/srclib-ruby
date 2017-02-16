require 'json'
require 'optparse'
require 'bundler'
require 'pathname'
require 'set'
require 'ostruct'

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
      analyzed_gemfiles = []

      all_gemspecs = find_gems('.')
      all_gemspec_names = all_gemspecs.map{ |gemspec, gem| gem[:name] } # these won't be added as deps

      source_units = all_gemspecs.map do |gemspec, gem|
        Dir.chdir(File.dirname(gemspec))
        deps = gem[:dependencies] || []
        if File.exist?("Gemfile")
          deps = deps.concat(Bundler.definition(true).dependencies)
          analyzed_gemfiles.push(File.expand_path("Gemfile"))
        end
        #group by dep name. This is so we don't add two or more of the same dep
        dep_groups = deps.group_by{|dep| dep.name}

        #Filter: dont add dev dependencies, or redundant deps (deps with names of gemspec files)
        valid_deps = []
        dep_groups.each do |dep_name, dep_group|
          next if all_gemspec_names.include?(dep_name)
          is_valid = true
          dep_group.each do |dep|
            next if !is_valid
            is_valid = dep_is_valid(dep)
          end
          valid_deps.push(dep_group[0]) if is_valid
        end

        files = find_scripts(File.dirname(gemspec)).map do |script_path|
          Pathname.new(script_path).relative_path_from(pre_wd)
        end
        files.push(".") # Hack: This is so this gets elected as top level over find_scripts below

        locked_deps = get_locked_dep_versions(valid_deps, gem)
        gem.delete(:date)
        gem[:dependencies] = locked_deps
        gem_dir = Pathname.new(gemspec).relative_path_from(pre_wd).parent

        {
          'Name' => gem[:name],
          'Version' => gem[:version],
          'Type' => 'rubygem',
          'Dir' => gem_dir,
          'Licenses' => gem[:licenses],
          'License' => gem[:license],
          'Files' => files,
          'Dependencies' => locked_deps,
          'Data' => gem,
          'Ops' => {'depresolve' => nil, 'graph' => nil},
        }
      end

      # Ignore standard library
      if @opt[:repo] != "github.com/ruby/ruby"
        Dir.chdir(pre_wd) # Reset working directory to initial root
        scripts = find_scripts('.').map do |script_path|
          Pathname.new(script_path).relative_path_from(pre_wd)
        end

        scripts.sort! # For testing consistency

        # If scripts were found, append to the list of source units
        if scripts.length > 0
          if File.exist?("Gemfile") && !analyzed_gemfiles.include?(File.expand_path("Gemfile"))
            deps = Bundler.definition(true).dependencies.select{|dep| dep_is_valid(dep) && !all_gemspec_names.include?(dep.name)}
            locked_deps = get_locked_dep_versions(deps, nil)
          end

          source_units << {
            'Name' => '.',
            'Type' => 'ruby',
            'Dir' => '.',
            'Files' => scripts,
            'Dependencies' => locked_deps,
            'Data' => {
              'name' => 'rubyscripts',
              'files' => scripts,
              'Dependencies' => locked_deps
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
    def find_scripts(dir)
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
        spec = Gem::Specification.load(spec_file) rescue nil
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
      is_dev_type = dep.type.to_s == "development"
      is_dev_group = false
      if dep.groups
        is_dev_group = (dep.groups.include?(:development) || dep.groups.include?(:test))
      end

      return (!is_dev_group && !is_dev_type)
    end

    # if there is a locked version from Gemfile.lock, then use that. Otherwise, return dep range
    # if gem given (gemspec found), don't return dep if it is itself the gemspec
    def get_locked_dep_versions(curr_deps, gem)
      all_deps = []
      curr_specs = Bundler::LockfileParser.new(Bundler.read_file(Bundler.default_lockfile)).specs rescue []
      curr_deps.each do |curr_dep|
        found_spec = curr_specs.detect {|spec| spec.name.to_s == curr_dep.name.to_s}
        dep_to_push = OpenStruct.new
        #scope = []
        if found_spec
          dep_to_push.name = found_spec.name
          dep_to_push.version = found_spec.version
        else
          dep_to_push.name = curr_dep.name
          dep_to_push.version = curr_dep.requirement
        end
        #scope = curr_dep.groups if curr_dep.groups
        #dep_to_push.scope = scope

        all_deps.push(dep_to_push)
      end
      #return all_deps.map {|dep| {:name => dep.name, :version => dep.version, :scope => dep.scope}}.sort{|a, b| a[:name] <=> b[:name]}
      return all_deps.map {|dep| {:name => dep.name, :version => dep.version}}.sort{|a, b| a[:name] <=> b[:name]}
    end
  end
end
