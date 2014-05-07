# encoding: utf-8

require 'spec_helper'
require 'oddb2xml/fi'

module Kernel
  def fi_capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval "$#{stream} = #{stream.upcase}"
    end
    result
  end
end

RSpec::Matchers.define :have_option do |option|
  match do |interface|
    key = option.keys.first
    val = option.values.first
    options = interface.instance_variable_get(:@options)
    options[key] == val
  end
  description do
      "have #{option.keys.first} option as #{option.values.first}"
  end
end

shared_examples_for 'any interface for product' do
  it { fi_capture(:stdout) { cli.should respond_to(:run) } }
  it 'should run successfully' do
    fi_capture(:stdout){ cli.run }.should match(/products/)
  end
end

describe Oddb2xml::FI do
  # Setting ShouldRun to false and changing one -> if true allows you
  # to run easily the failing test
  include ServerMockHelper
  before(:each) do
    @savedDir = Dir.pwd
    cleanup_directories_before_run
    setup_server_mocks
    Dir.chdir(Oddb2xml::WorkDir)
  end
  after(:each) do
    Dir.chdir(@savedDir) if @savedDir and File.directory?(@savedDir)
  end
  context 'when -o fi given' do
    let(:cli) do
      opts = {
        :fi           => :fi,
        }
      Oddb2xml::Cli.new(opts)
    end
    it_behaves_like 'any interface for product'
    it 'should have fi option' do
      cli.should have_option(:fi => :fi)
    end

    it 'should generate a valid oddb_fi_de.xml' do
      res = fi_capture(:stdout){ cli.run }
      fi_filename = File.expand_path(File.join(Oddb2xml::WorkDir, 'oddb_fi_de.xml.xml'))
      `ls -l #{fi_filename}`.should match(fi_filename)
      res.should match(/oddb_fi_de.xml/)
      File.exists?(fi_filename).should be_true
      fi_xml = IO.read(fi_filename)
      doc = REXML::Document.new File.new(fi_filename)
      fi_xml.should match(/<COMPNO>7601001320451</)
      XPath.match( doc, "//date" ).find_all{|x| x.text.match('ZYVOXID Filmtabl 600 mg') }.size.should == 1
      XPath.match( doc, "//title").find_all{|x| x.text.match('ZYVOXID Filmtabl 600 mg') }.size.should == 1
      XPath.match( doc, "//lang" ).find_all{|x| x.text.match('ZYVOXID Filmtabl 600 mg') }.size.should == 1
      FI::Sections.each do
        |sectionId, sectionName|
        cmd = "XPath.match( doc, '//#{sectionName}' ).find_all{|x| true }.size.should >= 1 }"
        $stderr.puts cmd
        eval cmd
      end
    end
  end
end
