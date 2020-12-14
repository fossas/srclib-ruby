# srclib-ruby [![Build Status](https://travis-ci.org/sourcegraph/srclib-ruby.png?branch=master)](https://travis-ci.org/sourcegraph/srclib-ruby)
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Ffossas%2Fsrclib-ruby.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Ffossas%2Fsrclib-ruby?ref=badge_shield)

## YARD

srclib-ruby uses [Loren Segal's](http://gnuu.org/)
[YARD](https://github.com/lsegal/yard) for Ruby analysis. A git subtree of the
[Sourcegraph](https://sourcegraph.com) fork of YARD is in the `yard/`
subdirectory. Commits to that subtree should be regularly sent upstream to the
[github.com/sourcegraph/yard](https://github.com/sourcegraph/yard) fork.

## Running tests

The `make test` target analyzes sample repositories in `testdata/case` and
checks that the actual output matches the expected output (which is committed to
the repository).

The sample repositories are git submodules, so you'll have to `git submodule
init && git submodule update` the first time you want to run the tests.

The output of the analyzer differs a bit depending on the version of Ruby you
have installed. The expected output was generated using Ruby 2.2.2. If you're
finding that your output differs from the expected, try **both** generating the
stdlib index and running the tests with that version of Ruby. If you're using
[rvm](https://rvm.io), this means running the following commands:

```
# in case you built the stdlib index using a different version of Ruby (e.g.,
# your system Ruby)
rm -rf ruby-2.2.2/.yardoc

# rebuild the stdlib index using Ruby 2.2.2 (run `rvm install 2.2.2` if you
# haven't already installed Ruby 2.2.2)
rvm 2.2.2 do make stdlib

# install gem deps for the test repos using Ruby 2.2.2
rvm 2.2.2 do make test-dep

# run the tests with Ruby 2.2.2
rvm 2.2.2 do make test
```

The same applies when you're generating new expected test output (after making
an improvement to the code, for example).

If you're having trouble getting your output to match the expected, post an
issue.

## Using srclib-ruby in Windows/Cygwin environment

Windows with Cygwin installed is required as a prerequisite. `srclib-ruby` has been tested with:
```
CYGWIN_NT-6.1-WOW Diana 2.0.4(0.287/5/3) 2015-06-09 12:20 i686 Cygwin
```

### Windows installation instructions

* Download and install Ruby 2.2.2 using [RubyInstaller](http://rubyinstaller.org/downloads/). The
  [x64 version]((http://dl.bintray.com/oneclick/rubyinstaller/rubyinstaller-2.2.2.exe)) has worked successfully. Make
  sure that `ruby.exe` is included in your path.
* Download the Development Kit from [RubyInstaller](http://rubyinstaller.org/downloads/). The [x64 version](
  http://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe) is known to work successfully. Extract the self-extracting archive somewhere (say `C:\rbdevkit`) and switch to this directory.
* Run ```ruby dk.rb init``` to generate `config.yml`.
* Edit `config.yml` and add a line like ` - RUBY-INSTALLATION-DIR`. For example, ` - C:/ruby22-x64`.
* Run ```ruby dk.rb install```..
* Run ```gem install bundler -v 1.6.9```. Using 1.6.x is important because srclib-ruby is supposed to work with 1.6.x.
* Run ```gem install gem-exefy```. This tool replaces .bat files in RubyInstaller with .exe. Ensure that you have installed DevKit as described above. Otherwise, `gem` won't work.
* Run ```gem exefy --all``` to convert .bat files to .exe in RubyInstaller (for example, it will create `bundle.exe` and remove `bundle.bat`
* Now, you are ready to run ```make``` in your srclib-ruby directory. It will take some time while Ruby downloads required files and then Yard builds the cache of Ruby 2.2.2 files.

### Issue with OpenSSL

Ruby may not provide a default OpenSSL certificate authorities file. Thus, `srclib-ruby` may unable to communicate with external sites. Here is the [workaround
](https://gist.github.com/fnichol/867550) - see `The Manual Way` there.

## TODO

* Check whether Ruby stdlib works
* Check whether xrefs work
* Add Travis-CI test for `src test` test cases and YARD specs


## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Ffossas%2Fsrclib-ruby.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Ffossas%2Fsrclib-ruby?ref=badge_large)