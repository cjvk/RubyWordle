#!/usr/bin/ruby -w

# copied from https://github.com/charlesreid1/five-letter-words
DICTIONARY_FILE_LARGE = "sgb-words.txt"
DICTIONARY_FILE_SMALL = "sgb-words-small.txt"
DICTIONARY_FILE = DICTIONARY_FILE_LARGE

def populate_all_words
  d = {}
  File.foreach(DICTIONARY_FILE).with_index do |line, line_num|
    d[line.chomp] = line_num
  end
  d
end

def play(d)
  puts "Welcome to wordle!"
  for guess in 1..6
    puts "You are on guess #{guess}/6. There are #{d.size} matching words remaining."
    print "Enter your guess, or PRINT: ==> "
    word = gets.chomp
    if word == "PRINT"
      d.each do |key, value|
        puts key
      end
      return
    end
    print "Enter the response (!?-): ==> "
    response = gets.chomp
    filter(d, word, response)
  end
end

def filter(d, word, response)
  for i in 0..4
    letter = word[i]
    case response[i]
    when "!"
      d.delete_if { |key, value| key[i] != letter }
    when "?"
      d.delete_if { |key, value| key[i] == letter || !key[letter] }
    when "-"
      d.delete_if { |key, value| key[letter] }
    else
      raise "unrecognized response character"
    end
  end
end

d = populate_all_words
play(d)
