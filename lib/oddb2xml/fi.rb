# encoding: utf-8

require 'oddb2xml/util'

module Oddb2xml

  class FI
    Sections = {
      :section1 => :Title,
      :section2 => :Composition,
      :section3 => :GalenicForm,
      :section4 => :Indications,
      :section5 => :Dosage,
      :section6 => :ContraIndications,
      :section7 => :Warnings,
      :section8 => :Interactions,
      :section9 => :Pregnancy,
      :section10 => :DrivingAbility,
      :section11 => :UndesiredEffects,
      :section12 => :OverDosage,
      :section13 => :UndesiredEffects,
      :section14 => :Pharmacocinetics,
      :section15 => :PreClinicResults,
      :section16 => :OhterIndications,
      :section17 => :AuthNrs,
      :section18 => :Packages,
      :section19 => :AuthHolder,
      :section20 => :ReleaseDate,
      }
   
    def initialize(args)
      @options = args
      Oddb2xml.save_options(@options)
      @mutex = Mutex.new
    end
  end
end