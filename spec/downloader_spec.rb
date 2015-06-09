# encoding: utf-8

require 'spec_helper'

shared_examples_for 'any downloader' do
  # this takes 5 sec. by call for sleep
  it 'should count retry times as retrievable or not', :slow => true do
    expect {
      Array.new(3).map do
        Thread.new do
          @downloader.send(:retrievable?).should be(true)
        end
      end.map(&:join)
    }.to change {
      @downloader.instance_variable_get(:@retry_times)
    }.from(3).to(0)
  end
end

def common_before
  @savedDir = Dir.pwd
  cleanup_directories_before_run
  Dir.chdir(Oddb2xml::WorkDir)
end

def common_after
  Dir.chdir(@savedDir) if @savedDir and File.directory?(@savedDir)
end

describe Oddb2xml::EphaDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::EphaDownloader.new
    common_before
  end
  after(:each) do common_after end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:csv) {
      VCR.configure do |c|
        c.before_record(:epha) do |i|
          i.response.body = i.response.body.split("\n")[0..5].join("\n")
          i.response.headers['Content-Length'] = i.response.body.size
        end
      end
      VCR.use_cassette("Epha", :tag => :epha) do
        @downloader.download
      end
    }
    it 'should read csv as String' do
      csv.should be_a String
      csv.bytes.should_not nil
    end
    it 'should clean up current directory' do
      expect { csv }.not_to raise_error
      # File.exist?('epha_interactions.csv').should eq(false)
    end
  end
end

describe Oddb2xml::BagXmlDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::BagXmlDownloader.new
    common_before
  end
  after(:each) do common_after end
  
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:xml) {
      VCR.configure do |c|
        c.before_record(:bag_xml) do |i|
          zip = File.read(File.join(Oddb2xml::SpecData, 'XMLPublications.zip'))
          i.response.body = zip
          i.response.headers['Content-Length'] = File.size(File.join(Oddb2xml::SpecData, 'XMLPublications.zip'))
        end
      end
      VCR.use_cassette("bag", :tag => :bag_xml, :preserve_exact_body_bytes => true) do
        @downloader.download
      end
    }
    it 'should parse zip to string' do
        xml.should be_a String
        xml.length.should_not == 0
    end
    it 'should return valid xml' do
      xml.should =~ /xml\sversion="1.0"/
      xml.should =~ /Preparations/
      xml.should =~ /DescriptionDe/
    end
  end
end

if false
describe Oddb2xml::SwissIndexDownloader do
  include ServerMockHelper
  before(:each) do
    common_before
  end
  after(:each) do common_after end
  context 'Pharma with DE' do
    before(:each) do
      @downloader = Oddb2xml::SwissIndexDownloader.new({}, :pharma, 'DE')
    end
    it_behaves_like 'any downloader'
    context 'when download_by is called with DE' do
      let(:xml) {
        VCR.use_cassette("SwissIndex_DE") do
          @downloader.download
        end
      }
      it 'should parse response hash to xml' do
        xml.should be_a String
        xml.length.should_not == 0
        xml.should =~ /xml\sversion="1.0"/
      end
      it 'should return valid xml' do
        xml.should =~ /PHAR/
        xml.should =~ /ITEM/
      end
    end
  end
  context 'NonPharma with FR' do
    before(:each) do
      @downloader = Oddb2xml::SwissIndexDownloader.new({}, :nonpharma, 'FR')
    end
    it_behaves_like 'any downloader'
    context 'when download_by is called with FR' do
      let(:xml) {
        VCR.use_cassette("SwissIndex_FR") do
          @downloader.download
        end
      }
      it 'should parse response hash to xml' do
        xml.should be_a String
        xml.length.should_not == 0
        xml.should =~ /xml\sversion="1.0"/
      end
      it 'should return valid xml' do
        xml.should =~ /NONPHAR/
        xml.should =~ /ITEM/
      end
    end
  end
end

describe Oddb2xml::SwissmedicDownloader do
  include ServerMockHelper
  context 'orphan' do
    before(:each) do
      @downloader = Oddb2xml::SwissmedicDownloader.new(:orphan)
      common_before
    end
    after(:each) do common_after end
    it_behaves_like 'any downloader'
    context 'download_by for orphan xls' do
      let(:bin) {
        VCR.use_cassette("SwissMedic") do
          @downloader.download
        end
      }
      it 'should return valid Binary-String' do
        unless [:orphan, :package].index(@downloader.type)
          bin.should be_a String
          bin.bytes.should_not nil
        end
      end
      it 'should clean up current directory' do
        unless [:orphan, :package].index(@downloader.type)
          expect { bin }.not_to raise_error
          File.exist?('oddb_orphan.xls').should eq(false)
        end
      end
    end
  end
  context 'fridge' do
    before(:each) do
      @downloader = Oddb2xml::SwissmedicDownloader.new(:fridge)
      common_before
    end
    context 'download_by for fridge xls' do
      let(:bin) {
        VCR.use_cassette("SwissMedic") do
          @downloader.download
        end
      }
      it 'should return valid Binary-String' do
        bin.should be_a String
        bin.bytes.should_not nil
      end
    end
  end
  context 'package' do
    before(:each) do
      @downloader = Oddb2xml::SwissmedicDownloader.new(:package)
    end
  end
end

describe Oddb2xml::SwissmedicInfoDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::SwissmedicInfoDownloader.new
    common_before
  end
  after(:each) do common_after end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:xml) {
      VCR.use_cassette("SwissmedicInfo") do
        @downloader.download
      end
    }
    it 'should parse zip to String' do
      xml.should be_a String
      xml.length.should_not == 0
    end
    it 'should return valid xml' do
      xml.should =~ /xml\sversion="1.0"/
      xml.should =~ /medicalInformations/
      xml.should =~ /content/
    end
    it 'should clean up current directory' do
      expect { xml }.not_to raise_error
      File.exist?('swissmedic_info.zip').should eq(false)
    end
  end
end

describe Oddb2xml::EphaDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::EphaDownloader.new
    common_before
  end
  after(:each) do common_after end
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:csv) {
      VCR.use_cassette("Epha") do
        @downloader.download
      end
    }
    it 'should read csv as String' do
      csv.should be_a String
      csv.bytes.should_not nil
    end
    it 'should clean up current directory' do
      expect { csv }.not_to raise_error
      # File.exist?('epha_interactions.csv').should eq(false)
    end
  end
end

describe Oddb2xml::BMUpdateDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::BMUpdateDownloader.new
    common_before
  end
  after(:each) do common_after end
  
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:txt) {
      VCR.use_cassette("BMUpdate") do
        @downloader.download
      end
    }
    it 'should read txt as String' do
      txt.should be_a String
      txt.bytes.should_not nil
    end
    it 'should clean up current directory' do
      expect { txt }.not_to raise_error
      # File.exist?('oddb2xml_files_bm_update.txt').should eq(false)
    end
  end
end

describe Oddb2xml::LppvDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::LppvDownloader.new
    common_before
  end
  after(:each) do common_after end
  
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:txt) {
      VCR.use_cassette("Lppv") do
        @downloader.download
      end
    }
    it 'should read txt as String' do
      txt.should be_a String
      txt.bytes.should_not nil
    end
    it 'should clean up current directory' do
      expect { txt }.not_to raise_error
#      File.exist?('oddb2xml_files_lppv.txt').should eq(false)
    end
  end
end

describe Oddb2xml::MigelDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::MigelDownloader.new
    common_before
  end
  after(:each) do common_after end
  
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:bin) {
      VCR.use_cassette("Migel") do
        @downloader.download
      end
    }
    it 'should read xls as Binary-String' do
      bin.should be_a String
      bin.bytes.should_not nil
    end
    it 'should clean up current directory' do
      expect { bin }.not_to raise_error
      File.exist?('oddb2xml_files_nonpharma.txt').should eq(false)
    end
  end
end

describe Oddb2xml::MedregbmDownloader do
  include ServerMockHelper
  before(:each) do
    common_before
  end
  after(:each) do common_after end

  context 'betrieb' do
    before(:each) do
      @downloader = Oddb2xml::MedregbmDownloader.new(:company)
    end
    it_behaves_like 'any downloader'
    context 'download betrieb txt' do
      let(:txt) {
        VCR.use_cassette("MedregbmBetrieb") do
          @downloader.download
        end
      }
      it 'should return valid String' do
        txt.should be_a String
        txt.bytes.should_not nil
      end
      it 'should clean up current directory' do
        expect { txt }.not_to raise_error
        File.exist?('oddb_company.xls').should eq(false)
      end
    end
  end
  context 'person' do
    before(:each) do
      @downloader = Oddb2xml::MedregbmDownloader.new(:person)
    end
    context 'download person txt' do
      let(:txt) {
        VCR.use_cassette("MedregbmPerson") do
          @downloader.download
        end
      }
      it 'should return valid String' do
        txt.should be_a String
        txt.bytes.should_not nil
      end
      it 'should clean up current directory' do
        expect { txt }.not_to raise_error
        File.exist?('oddb_person.xls').should eq(false)
      end
    end
  end  if false
end

describe Oddb2xml::ZurroseDownloader do
  include ServerMockHelper
  before(:each) do
    @downloader = Oddb2xml::ZurroseDownloader.new
    common_before
  end
  after(:each) do common_after end
  
  it_behaves_like 'any downloader'
  context 'when download is called' do
    let(:dat) {
      VCR.use_cassette("Medregbm") do
        @downloader.download
      end
    }
    it 'should read dat as String' do
      dat.should be_a String
      dat.bytes.should_not nil
    end
    it 'should clean up current directory' do
      expect { dat }.not_to raise_error
      File.exist?('oddb2xml_zurrose_transfer.dat').should eq(false)
    end
  end
end
end