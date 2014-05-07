#!/usr/bin/env ruby
# Niklaus Giger, 2015
# Small helper scripts to extract Infos for selected IKSRN from an xml file

require 'nokogiri'
require 'fileutils'
work = 'AipsDownload_20140507.xml'
# 45928 (Künzle), 62184 (Cipralex® Filmtabletten),  58267 for Isentress.
regexp = /45928|62184|58267/
doc = Nokogiri::XML(open(work))

ausgabe = work.sub('.xml', '.neu')
f = File.open(work)
doc = Nokogiri::XML(f)
doc.css('//medicalInformation').each do
  |node|
  if regexp.match(authNrs)
    authNrs = node.xpath('//authNrs').text
  else
    node.remove
  end
end
File.open(ausgabe, 'w+') {|out| out.write doc.to_xml }
system("ls -l #{work} #{ausgabe}")

