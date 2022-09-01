#!/usr/bin/ruby -w

def scrape_file
  nyt_file = ARGV[0]
  all_words = []
  File.foreach(nyt_file) do |line|
    # first line is what we want
    cigar_index = line.index('cigar')
    current_index = cigar_index - 1 # start with the quote
    while line[current_index] == '"'
      word = line[current_index+1,5]
      all_words.append(word)
      current_index += 8
    end
    total_solutions = all_words.length
    puts "#{total_solutions} solutions scraped (2309 on 9/1/2022)"
    current_index += 5
    while line[current_index] == '"'
      word = line[current_index+1,5]
      all_words.append(word)
      current_index += 8
    end
    total_valid_non_solutions = all_words.length - total_solutions
    puts "#{total_valid_non_solutions} valid non-solutions scraped (12546 on 9/1/2022)"
    puts "#{all_words.length} total words (14855 on 9/1/2022)"
    break
  end

  # in-place sort
  all_words.sort!

  # note: this will overwrite an existing file
  File.open('valid-wordle-words-temp.txt','w') do |f|
    f.puts '# All valid wordle words'
    f.puts "# scraped from NYT via scrape_nyt.rb on #{Time.new.ctime}"
    f.puts '# Wordle webpage > view source > find last "http", should be a Javascript game asset'
    f.puts '# e.g. https://www.nytimes.com/games-assets/v2/wordle.c8bbc972bb478984977b7b8995a51a1770bf4b08.js'
    f.puts '# usage: ruby scrape_nyt.rb wordle.c8bbc972bb478984977b7b8995a51a1770bf4b08.js'
    f.puts '# This file supports comments, the first character must be #'
    all_words.each {|word| f.puts word}
  end
end

scrape_file
