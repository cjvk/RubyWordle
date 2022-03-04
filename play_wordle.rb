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
    while true do
      print "Enter a guess, or (p)rint, (h)int, (q)uit: ==> "
      choice = gets.chomp
      case choice
      when "p"
        max_print = 30
        d.each do |key, value|
          puts key
          break if (max_print = max_print - 1) == 0
        end
      when "h"
        hint(d)
      when "q"
        return
      else # assume anything else is a guess
        word = choice
        puts "word=#{word}"
        print "Enter the response (!?-): ==> "
        response = gets.chomp
        filter(d, word, response)
        break
      end
    end
  end
end

def hint(d)
  num_remaining = d.size
  puts "remaining: #{num_remaining}"
  character_dictionary = {}
  for c in 97..122
    character_dictionary[c.chr] = 0
  end
  d.each do |word, line_num|
    character_dictionary.each do |c, num_so_far|
      if word[c]
        character_dictionary[c] = num_so_far + 1
      end
    end
  end
  top_n = 3
  top_n_dict = {}
  for i in 0...top_n
    puts i
    next_largest = character_dictionary.max_by{|k,v| (v==num_remaining||top_n_dict.has_key?(k)) ? 0 : v}
    top_n_dict[next_largest[0]]=next_largest[1]
  end
  puts top_n_dict
  d.each do |word, line_num|
    count = 0
    top_n_dict.each do |c, num_occurrences|
      count = count + 1 if word[c]
    end
    puts "#{word} is a GREAT guess" if count == top_n
    puts "#{word} is a good guess" if count == (top_n-1)
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
