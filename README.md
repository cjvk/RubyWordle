# RubyWordle

# calculate problematic patterns in wordle
% ruby problem_words.rb

# example grep command for wordle 254

# creation of maybe-singular words
cat sgb-words.txt | grep '....s' | sed 's/\([a-z]\{4\}\)s/\1/g' | sort > sgb-words-maybe-singulars.txt

# source of four_letter_words.txt
https://gist.github.com/jacoby/19a30ff256ef7736a4f53e7ddc2c9474

# words which should be kept (singulars are not valid)
comm -23 sgb-words-maybe-singulars.txt four_letter_words.txt

# valid singulars
comm -12 sgb-words-maybe-singulars.txt four_letter_words.txt

# sorted plurals
comm -12 sgb-words-maybe-singulars.txt four_letter_words.txt | sed 's/\([a-z]\{4\}\)/\1s/g' > sgb-words-plurals-sorted.txt

# filter out plurals
comm -23 sgb-words-sorted.txt sgb-words-plurals-sorted.txt > sgb-words-without-plurals-sorted.txt

# remove past-tense
cat sgb-words-without-plurals-sorted.txt| grep -v '...ed' > sgb-words-without-plurals-without-past-tense-sorted.txt
