# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
include Parslet
VERBOSE_MESSAGES = true

class DoseParser < Parslet::Parser

  # Single character rules
  rule(:lparen)     { str('(') >> space? }
  rule(:rparen)     { str(')') >> space? }
  rule(:comma)      { str(',') >> space? }

  rule(:space)      { match('\s').repeat(1) }
  rule(:space?)     { space.maybe }

  # Things
  rule(:digit) { match('[0-9]') }
  rule(:digits) { digit.repeat(1) }
  rule(:number) {
    (
      str('-').maybe >> (
        str('0') | (match('[1-9]') >> match('[0-9\']').repeat)
      ) >> (
            str('.') >> digit.repeat(1)
      ).maybe >> (
        match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
      ).maybe
    )
  }
  rule(:radio_isotop) { match['a-zA-Z'].repeat(1) >> str('(') >> digits >> str('-') >> match['a-zA-Z'].repeat(1-3) >> str(')') >>
                        ((space? >> match['a-zA-Z']).repeat(1)).repeat(0)
                        } # e.g. Xenonum (133-Xe) or yttrii(90-Y) chloridum zum Kalibrierungszeitpunkt
  rule(:identifier) { (match['a-zA-Zéàèèçïöäüâ'] | digit >> str('-'))  >> match['0-9a-zA-Z\-éàèèçïöäüâ\'\/\.:%,'].repeat(0) }
  #  poliomyelitis typus 1 inactivatum (D-Antigen)
  rule(:name_with_parenthesis) {
    (match('[a-zA-Z]') >> ((match('[0-9]') >> space >> match('[a-zA-Z]')).maybe >>match('[a-zA-Z_\- \(\)]')).repeat) >> space?
  }
  # dose
  rule(:dose_unit)      { (
                           str('% V/V') |
                           str('µg') |
                           str('guttae') |
                           str('mg/ml') |
                           str('MBq') |
                           str('mg') |
                           str('Mg') |
                           str('g') |
                           str('l') |
                           str('µl') |
                           str('ml') |
                           str('U.I.') |
                           str('U.') |
                           str('Mia. U.') |
                           str('%')
                          ).as(:unit) }
  rule(:qty_range)       { (number >> space? >> str('-') >> space? >> number).as(:qty_range) }
  rule(:qty_unit)       { (qty_range | dose_qty) >> space? >> dose_unit }
  rule(:dose_qty)       { number.as(:qty) }
  rule(:dose)           { (qty_unit | dose_qty |dose_unit) >>
#                          (space >> (str('ad pulverem') | str('pro charta') | str('pro dosi'))).repeat(0,1)
                          (space >> (str('ad pulverem') | str('pro charta') | str('pro dosi') )).repeat(0)
                        }
  root :dose

end

class IntLit   < Struct.new(:int)
  def eval; int.to_i; end
end
class QtyLit   < Struct.new(:qty)
  def eval; qty.to_i; end
end
class Addition < Struct.new(:left, :right)
  def eval; left.eval + right.eval; end
end

class DoseTransformer < Parslet::Transform
  rule(:int => simple(:int))        { IntLit.new(int) }
  rule(:number => simple(:nb)) {
    nb.match(/[eE\.]/) ? Float(nb) : Integer(nb)
  }
  rule(
    :left => simple(:left),
    :right => simple(:right),
    :op => '+')                     { Addition.new(left, right) }
  rule(
    :qty_range    => simple(:qty_range),
    :unit   => simple(:unit))  {
      ParseDose.new(qty_range, unit)
    }
  rule(
    :qty    => simple(:qty),
    :unit   => simple(:unit))  {
      ParseDose.new(qty, unit)
    }
  rule(
    :unit    => simple(:unit))  { ParseDose.new(nil, unit) }
  rule(
    :qty    => simple(:qty))  { ParseDose.new(qty, nil) }
end


class SubstanceParser < DoseParser

  rule(:operator)   { match('[+]') >> space? }

  # Grammar parts
  rule(:sum)        {
    number.as(:left) >> operator.as(:op) >> expression.as(:right) }

  rule(:farbstoff) { ((str('antiox.:') | str('color.:'))  >> space).maybe >>  (str('E').as(:farbstoff) >> space >> digits.as(:digits) >> match['(a-z)'].repeat(0,3)) } # Match Wirkstoffe like E 270
  rule(:name_simple_part) { identifier | identifier >> (space >> identifier).repeat(1) }
  rule(:substance_in_parenthesis) { (name_complex_part >>  space?).repeat(1) >> (comma >> (name_simple_part >> space?).repeat(0)).repeat(0) }
  rule(:name_complex_part) { identifier |
                             str('>') |
                           digit.repeat >> space >> dose_unit.absent? >> any.repeat | # match stuff like typus 1 inactivatum
                            str('(') >> substance_in_parenthesis >> str(')') >> digit.repeat(0,1) >> str('-like:').maybe      # Match name_with_parenthesis like  (D-Antigen)
                           }
  rule(:der) { (str('DER:')  >> space >> (digit >> match['\.-']).maybe >> digit >> str(':') >> digit).as(:der) } # DER: 1:4 or DER: 3.5:1 or DER: 6-8:1
  rule(:substance_name) { (name_simple_part >> (space? >> name_complex_part).repeat(0)).as(:substance_name) }
  rule(:substance) { (farbstoff | (radio_isotop.as(:substance_name) | substance_name) >> space? >> dose.maybe.as(:dose)).as(:substance) }
  # excipiens ad pulverem pro 1000 mg
  # excipiens ad solutionem pro 2 ml
  # excipiens ad solutionem pro 3 ml corresp. 50 µg
  # excipiens ad solutionem pro 1 ml corresp. ethanolum 59.5 % V/V

  rule(:excipiens) { (str('excipiens') >> space >>
                      (
#                      str('ad solutionem pro') >> space >> str('3 ml corresp. 50 µg')
                        str('ad solutionem pro').as(:ad_solutionem) >> space >> dose.as(:dose) >> space >>
                        str('corresp.') >>
                        (space >> substance_name.as(:substance_corresp)).maybe >>
                        (space >> dose.as(:dose_corresp))
                       ) |
                      (str('pro compresso').as(:pro_compresso)) |
                      (str('ad pulverem').as(:ad_pulverem) >>
                          (space >> str('corresp. suspensio reconstituta').as(:name_corresp)  >> space? >> dose.maybe).maybe >>
                          (space >> str('pro charta').as(:pro_charta)).maybe >>
                          (space >> str('pro').as(:pro) >> space >> dose).maybe
                      )
                     ).as(:excipiens)
                     }
  rule(:excipiensx) { ((str('excipiens') >> space >>
                       (str('ad solutionem pro').as(:pro) >>
                        space >> dose >>
                        (space >> str('corresp.')).maybe >>
                        (space >> dose.as(:dose_corresp1)).maybe >>
#                        (space >> substance_name.as(:substance_name)).maybe >>
#                        (space >> dose.as(:dose_corresp)).maybe >>
                       str('xxxx').maybe
                       ).maybe |
                      (
                       str('pro compresso').as(:pro).maybe |
                        (
                          str('ad pulverem').as(:pro).maybe >>
                          (space >> str('pro charta')).maybe >>
                          (space >> str('pro').as(:pro2) >> space >> dose).maybe
                        )
                      ).maybe # >> any.repeat(0).as(:filler)
                      # (str('ad pulverem') >> space? >> str('pro charta').maybe).maybe.as(:ad_pulverem)
#                      (
#                       ((str('ad pulverem') >> space? >> str('pro charta')).maybe.as(:ad_pulverem) >> space?)|
#                        (str('ad solutionem pro').as(:pro)  >> space >> dose)
#                      )>>
#                      ((space? >> (str('corresp. suspensio reconstituta') |
#                                   str('corresp.'))
#                                  .as(:name_corresp) >>
#                        (space >> substance_name.as(:substance_name)).maybe) >>
#                        (space >> dose).as(:dose_corresp).maybe
#                       ).maybe # >> any.repeat(0).as(:must_be_parsed)
                      )
                     ).as(:excipiens)
                   }
  rule(:additional_substance) { str(',') >> space >> one_substance }
#  rule(:named_substance) { (identifier >> space?).repeat(1).as(:substance_name) >> dose.as(:dose) >> str(':')} # worked for first line
  rule(:histamin) { str('U = Histamin Equivalent Prick').as(:histamin) }
  rule(:named_substance) { (identifier >> space?).repeat(1).as(:substance_name) >> dose.as(:dose) >> str(':') >>
                           (space >> (identifier >> space? >> dose.maybe >> (space? >> str('et') >> space?).maybe).repeat(1)).maybe}
  rule(:substance_residui) { str('residui:')    >> space >> substance }
  rule(:substance_conserv) { str('conserv.:')   >> space >> substance }
  #rule(:substance_corresp) { substance.as(:substance) >> space >> str('corresp.') >> space >> substance.as(:substance_corresp) }
  rule(:substance_corresp) { substance.as(:substance) >> space >> str('corresp.') >> space >>  (str('suspensio reconstituta') >> space).maybe >>
                             (substance_et | substance).as(:substance_corresp)  }
  rule(:substance_ut) { substance.as(:substance_ut) >> space >> str('ut') >> space >> substance }
  rule(:substance_et) { (substance.as(:substance_et) >> space >> str('et') >> space).repeat(1) >> (substance_corresp | substance) }
  # rule(:substances)     { one_substance.repeat(0, 1) >> additional_substance.repeat(0) }
  rule(:all_substances) { one_substance.repeat(0, 1) >> additional_substance.repeat(0) }
  rule(:one_substance) { (der  | excipiens | histamin | named_substance | substance_residui | substance_conserv | substance_et | substance_ut | substance_corresp | substance ) }
#  rule(:one_substance) { (excipiens  ) }
#  rule(:one_substance) { str('excipiens ad pulverem pro') >> space >> dose  }
#  rule(:one_substance) { str('excipiens ad pulverem') >> space >> substance_corresp >> str('. suspensio reconstituta') >> space >> dose  }
  root :all_substances
  # root :excipiens
end

class SubstanceTransformer < DoseTransformer
  @@substances ||= []
  def SubstanceTransformer.clear_substances
    @@substances = []
  end
  def SubstanceTransformer.substances
    @@substances
  end
  def SubstanceTransformer.add_substance(substance)
    @@substances << substance
  end
#  ==>  [{:excipiens=>{:dose=>{:qty=>"1"@28, :unit=>"ml"@30}, :substance_corresp=>{:substance_name=>"ethanolum"@42}, :dose_corresp=>{:qty=>"59.5"@52, :unit=>"% V/V"@57}}}]

  rule(:farbstoff => simple(:farbstoff),
       :digits => simple(:digits)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new("#{dictionary[:farbstoff]} #{dictionary[:digits]}")
  }
  rule(:ad_solutionem => simple(:ad_solutionem),
       :dose => simple(:dose),
       :substance_corresp => simple(:substance_corresp)) {
    |dictionary|
    puts "#{__LINE__}: dictionary #{dictionary}"
       binding.pry
    dictionary[:substance]
  }
  rule(:substance => simple(:substance)) {
    |dictionary|
    puts "#{__LINE__}: dictionary #{dictionary}"
    dictionary[:substance]
  }
  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:substance_name].to_s.sub(/^excipiens /i, ''), dictionary[:dose])
  }
  rule(:substance_name => simple(:substance_name),
       :dose_corresp => simple(:dose_corresp),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:substance_name].to_s.sub(/^excipiens /i, ''), dictionary[:dose_corresp])
  }
  rule(:der => simple(:der),
       ) {
    |dictionary|
      puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:der].to_s)
  }
  rule(:histamin => simple(:histamin),
       ) {
    |dictionary|
      puts "#{__LINE__}: histamin dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:histamin].to_s)
  }
  rule(:substance => simple(:substance),
       :substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      ParseSubstance.new(dictionary[:substance], dictionary[:dose])
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
    ParseSubstance.new(dictionary[:one_substance])
  }
  rule(:excipiens => sequence(:excipiens)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
  binding.pry
    ParseSubstance.new(dictionary[:excipiens])
  }
  rule(:substance_name => sequence(:substance_name)) {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
    ParseSubstance.new(dictionary[:substance_name])
  }
  rule(
    :substances    => simple(:substances) ){
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      puts "substances is #{dictionary[:substances]}"
      binding.pry
      nil
    }
end

class CompositionParser < SubstanceParser

  rule(:composition) { (all_substances.as(:all_substances) ) }
  # "I) DTPa-IPV-Komponente (Suspension): toxoidum diphtheriae 30 U.I."

#  rule(:label) { (match(/[^:]/).repeat(1)).as(:label2) >> str(':') >> space }

  rule(:label) {
     (
                           str('V') |
                           str('IV') |
                           str('III') |
                           str('II') |
                           str('I') |
                           str('A') |
                           str('B') |
                           str('C') |
                           str('D') |
                           str('E')
                          ).as(:label) >> #  >> space?>> str('):').maybe >> space >>
    (  (str('):')  | str(')')) >> (space? >> (match(/[^:]/).repeat(1)).as(:label_description)  >> str(':')).maybe
      ) >> space
  }

  rule(:expression_comp) { label.maybe >> composition.as(:composition) }
  root :expression_comp
end

class CompositionTransformer < SubstanceTransformer
  @@curSubstance = nil
  rule(
    :qty    => simple(:qty),
    :unit   => simple(:unit))  {
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      dose = ParseDose.new(dictionary[:qty], dictionary[:unit])
      @@curSubstance.dose = dose if @@curSubstance
      nil
    } if false
  rule(
    :label    => simple(:label) ){
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      puts "label is #{dictionary[:label]}"
      binding.pry
      nil
    }
  rule(:label_description => simple(:label_description) ) {
    binding.pry
  }
  rule(
    :composition    => simple(:composition) ){
    |dictionary|
       puts "#{__LINE__}: dictionary #{dictionary}"
      puts "composition is #{dictionary[:composition]}"
      binding.pry
      nil
    }
end

class ParseDose
  attr_reader :qty, :unit
  def initialize(qty=nil, unit=nil)
    puts "ParseDose.new from #{qty.inspect} #{unit.inspect} #{unit.inspect}" if VERBOSE_MESSAGES
    if qty and (qty.is_a?(String) || qty.is_a?(Parslet::Slice))
      @qty  = qty.to_s.index('.') ? qty.to_s.to_f : qty.to_s.to_i
    elsif qty
      @qty  = qty.eval
    else
      @qty = 1
    end
    @unit = unit ? unit.to_s : nil
  end
  def eval
    self
  end
  def to_s
    return @unit unless qty
    "#{@qty} #{@unit}"
  end
  def ParseDose.from_string(string)
    puts "ParseDose.from_string #{string}" if VERBOSE_MESSAGES
    value = nil
    parser = DoseParser.new
    transf = DoseTransformer.new
    puts "#{__LINE__}: ==>  #{parser.parse(string)}" if VERBOSE_MESSAGES
    result = transf.apply(parser.parse(string))
  end
end

class ParseSubstance
  attr_accessor  :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose, :is_excipiens
  def initialize(name, dose=nil)
    puts "ParseSubstance.new from #{name.inspect} #{dose.inspect}" if VERBOSE_MESSAGES
    binding.pry unless name.is_a?(String)
    @name = name.to_s.split(/\s/).collect{ |x| x.capitalize }.join(' ').strip
    if dose
      @qty = dose.qty
      @unit = dose.unit
    end
    SubstanceTransformer.add_substance(self)
  end
  def qty
    @dose ? @dose.qty : @qty
  end
  def unit
    @dose ? @dose.unit : @unit
  end
  def eval
    puts "ParseSubstance.eval" if VERBOSE_MESSAGES
    self
  end
  def ParseSubstance.from_string(string)
    value = nil
    puts "ParseSubstance for string #{string}" if VERBOSE_MESSAGES
    parser = SubstanceParser.new
    transf = SubstanceTransformer.new
    puts "#{__LINE__}: ==>  #{parser.parse(string)}" if VERBOSE_MESSAGES
    result = transf.apply(parser.parse(string))
    return ParseSubstance.new(string) if /^E/.match(string) # Handle Farbstoffe
    if result.is_a?(Array)
      return result.first if result.first.is_a?(ParseSubstance)
      if result.first[:excipiens]
        if result.first[:excipiens].is_a?(Hash) and result.first[:excipiens] and result.first[:excipiens][:dose]
          substance = ParseSubstance.new(string)
          substance.is_excipiens = true
          substance.dose = result.first[:excipiens][:dose]
          if result.first[:excipiens][:substance_corresp]
            chemical_name = result.first[:excipiens][:substance_corresp][:substance_name].to_s
            substance.chemical_substance = ParseSubstance.new(chemical_name)
            substance.cdose = result.first[:excipiens][:dose_corresp] if result.first[:excipiens][:dose_corresp]
          end
          return substance
        end
        return ParseSubstance.new(result.first[:excipiens].to_s) if result.first[:excipiens].is_a?(Parslet::Slice)
        if result.first[:excipiens].is_a?(ParseSubstance)
          substance = result.first[:excipiens]
        else
          substance = result.first[:excipiens][:excipiens] if result.first[:excipiens][:excipiens].is_a?(ParseSubstance)
        end
        if val = result.first[:excipiens]
          name = val[:pro] ? val[:pro].to_s + ' ' : ''
          name += val[:dose_corresp].to_s  + ' ' if val[:dose_corresp]
          name += val[:ad_pulverem].to_s   + ' ' if val[:ad_pulverem]
          name  = name.sub(/^excipiens /i, '')
          substance = ParseSubstance.new(name, ParseDose.new(val[:qty].to_s, val[:unit].to_s))
          substance.is_excipiens = true
        end
        return substance
      end
      substance = result.first[:substance] if result.first[:substance]
      substance ||= result.first[:substance_et] if result.first[:substance_et]
      substance ||= result.first[:substance_corresp] if result.first[:substance_corresp]
      # pp result; pp substance; binding.pry
      substance.dose = ParseDose.new(result.first[:substance].qty.to_s, result.first[:substance].unit) if result.first[:substance]
      if result.first[:substance_corresp]
        if result.first[:substance_corresp].is_a?(Array)
          substance.chemical_substance = result.first[:substance_corresp].first[:substance_et]
        else
          # pp result;  binding.pry
          substance.chemical_substance = result.first[:substance_corresp] if result.first[:substance_corresp]
        end
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      elsif result.first[:substance_et]
        substance.chemical_substance = result.first[:substance_et]
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      elsif result.first[:substance_ut]
        substance.chemical_substance = result.first[:substance_ut]
        substance.cdose = ParseDose.new(substance.chemical_substance.qty.to_s, substance.chemical_substance.unit)
        substance.chemical_substance.dose =  substance.cdose
      end
      puts "ParseSubstance #{string} returning substance #{substance}" if VERBOSE_MESSAGES
      return substance
    end
    result
  end
end

class ParseComposition
  attr_accessor   :source, :label, :label_description, :substances, :galenic_form, :route_of_administration
  def initialize(source)
    @substances ||= []
    puts "ParseComposition.new from #{source.inspect} @substances #{@substances.inspect}" if VERBOSE_MESSAGES
    @source = source.to_s
  end
  def eval
    self
  end
  def ParseComposition.from_string(string)
    cleaned = string.gsub(/^"|["\n\.]+$/, '')
    value = nil
    puts "ParseComposition.from_string #{string}" if VERBOSE_MESSAGES
    SubstanceTransformer.clear_substances
    result = ParseComposition.new(cleaned)
    parser3 = CompositionParser.new
    transf3 = CompositionTransformer.new
    ast = transf3.apply(parser3.parse(cleaned))
    puts "#{__LINE__} #{ast}"
    # binding.pry if ast[:label_description]
    result.source = string
    result.label              = ast[:label].to_s             if ast[:label]
    result.label_description  = ast[:label_description].to_s if ast[:label_description]
    if ast.is_a?(Parslet::Slice)
    else
      ast.find_all{|x| x.is_a?(ParseSubstance)}.each{ |x| result.substances << x }
      result.substances = SubstanceTransformer.substances
      if ast.is_a?(Array) and  ast.first.is_a?(Hash)
        result.label              = ast.first[:label].to_s
        result.label_description  = ast.first[:label_description].to_s
      end
    end
    return result
  end
end
