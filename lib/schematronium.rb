require 'saxon-xslt'
require 'nokogiri' # Used for output parsing - there doesn't seem to be a clean way to manipulate Saxon::XML documents

# Library for running Schematron validators over XML documents
class Schematronium
  # Constructor for schematron checker
  #
  # @param [String, IO, File] schematron A schematron document, as either an IO object responding to #read,
  #   a filename, or a [String]
  # @param [String] phase The name of the schematron phase to run. By default, the
  #   special "run everything" phase is run
  def initialize(schematron, phase="'#ALL'")
    stages = %w|iso_dsdl_include.xsl
                iso_abstract_expand.xsl
                iso_svrl_for_xslt2.xsl|.map{|s| iso_file s}

    schematron = if schematron.respond_to? :read
                   Saxon.XML(schematron.read)
                 elsif schematron.kind_of? String
                   if File.file? schematron
                     Saxon.XML(File.open(schematron))
                   else
                     Saxon.XML(schematron)
                   end
                 else
                   raise "Unable to generate Schematron document from #{schematron.class.to_s}"
                 end

    # Run schematron through each stage of the iso_schematron pipeline
    #    then stringify the final result because Saxon.XSLT can't take
    #    an XML doc as input
    @sch_script = stages[0].transform(schematron)
    @sch_script = stages[1].transform(@sch_script)
    @sch_script = stages[2].transform(@sch_script, 'phase' => phase)

    @sch_script = Saxon::XSLT(@sch_script.to_s)
  end

  # Run schematron over xml document, returning the resulting XML
  #
  # @param [Saxon::XML::Document, IO, File] xml An XML document
  # @return [Nokogiri::XML::Document]
  def check(xml)
    xml = Saxon.XML(xml) unless xml.is_a? Saxon::XML::Document
    xml = Nokogiri::XML(@sch_script.transform(xml).to_s)
  end

  private

  # Helper method returning stages of iso_schematron XSLT transform
  #
  # @param [String] fname The filename of a stage in the iso_schematron XSLT
  # @return [Saxon::XSLT::Stylesheet]
  def iso_file(fname)
    Saxon.XSLT(File.open(File.join(File.dirname(File.expand_path(__FILE__)), 'iso-schematron-xslt2', fname)))
  end

end
