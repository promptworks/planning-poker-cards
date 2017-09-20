#!/usr/bin/env ruby

# Script to generate PDF cards suitable for planning poker
# from Pivotal Tracker [http://www.pivotaltracker.com/] CSV export.

# Inspired by Bryan Helmkamp's http://github.com/brynary/features2cards/

# Example output: http://img.skitch.com/20100522-d1kkhfu6yub7gpye97ikfuubi2.png

require 'rubygems'
require 'csv'
require 'ostruct'
require 'term/ansicolor'
require 'prawn'

class String; include Term::ANSIColor; end

file = ARGV.first

unless file
  puts "[!] Please provide a path to CSV file"
  exit 1
end

label_filter = ARGV[1]

# --- Read the CSV file -------------------------------------------------------

stories = CSV.read(file)
headers = stories.shift

# p headers
# p stories

# --- Hold story in Card class

class Card < OpenStruct
  def type
    @table[:type]
  end
end

# --- Create cards objects

cards = stories.map do |story|
  attrs =  { :story_id => story[0]   || '',
             :title    => story[1]   || '',
             :body     => story[13]  || '',
             :type     => story[6]   || '',
             :labels   => story[2] || '',
             :points   => story[7]   || '...',
             :owner    => story[13]  || '.'*50}

  Card.new attrs
end

cards.reject! { |card| !card.labels.include?(label_filter) } if label_filter

# p cards

# --- Generate PDF with Prawn & Prawn::Document::Grid

begin

outfile = File.basename(file, ".csv")

Prawn::Document.generate("#{outfile}.pdf",
   :page_layout => :portrait,
   :margin      => [50, 50, 50, 50],
   :page_size   => 'A4') do |pdf|

    @num_cards_on_page = 0

    #pdf.font "#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf"

    cards.each_with_index do |card, index|

      if index > 0 and index % 2 == 0
        pdf.start_new_page
        @num_cards_on_page = 1
      else
        @num_cards_on_page += 1
      end

      pdf.define_grid(:columns => 1, :rows => 2, :gutter => 42)

      row = @num_cards_on_page - 1
      column = 0

      padding = 12

      cell = pdf.grid( row, column )
      cell.bounding_box do

        pdf.stroke_color = "666666"
        pdf.stroke_bounds

        pdf.text card.labels, :size => 14

        pdf.bounding_box [pdf.bounds.left+padding, pdf.bounds.top-padding], :width => cell.width-padding do
          pdf.text card.story_id.to_s, :size => 28, :style => :bold
          pdf.text card.title, :size => 28, :style => :bold
          pdf.text "\n", :size => 16
          pdf.fill_color "444444"
          pdf.text card.body, :size => 16
          pdf.fill_color "000000"
        end
 
        pdf.text_box "Points: " + card.points,
          :size => 14, :at => [12, 50], :width => cell.width-18
        pdf.text_box "Owner: " + card.owner,
          :size => 10, :at => [12, 18], :width => cell.width-18
 
        pdf.fill_color "999999"
        pdf.text_box card.type.capitalize,  :size => 10,  :align => :right, :at => [12, 18], :width => cell.width-18
        pdf.fill_color "000000"

      end

    end

    # --- Footer
    #pdf.number_pages "#{outfile}.pdf", [pdf.bounds.left,  -28]
    #pdf.number_pages "<page>/<total>", [pdf.bounds.right-16, -28]
end

puts ">>> Generated PDF file in '#{outfile}.pdf' with #{cards.size} stories:".black.on_green

cards.each do |card|
  puts "* #{card.title}"
end

rescue Exception
  puts "[!] There was an error while generating the PDF file... What happened was:".white.on_red
  raise
end
