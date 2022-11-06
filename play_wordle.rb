#!/usr/bin/ruby -w

require 'yaml'
require_relative 'constants'
require_relative 'logging'
require_relative 'commands'
require_relative 'wordle_core'
require_relative 'twitter'
require_relative 'fingerprints'
require_relative 'tests'

module UI
  def self.main_menu(guess, d, show_menu: true)
    main_menu_array = [
      ' ----------------------------------------------------------.',
      '|                        Main Menu                         |',
      '|                                                          |',
      "|   You are on guess #{guess}/6. #{remaining_count_string(d)}",
      '|                                                          |',
      "|   Enter a guess, or 'help' for more commands             |",
      ' ----------------------------------------------------------/',
    ].map{|s| s.length<60 ? s.pad_right_to_length(60, termination_character: '|') : s}
    if show_menu
      UI::padded_puts ''
      main_menu_array.each{|s| padded_puts s}
    end
    UI.prompt_for_input('')
  end

  def self.play(d)
    [
      '',
      '----------------------------------------------------------',
      '|                                                        |',
      '|                   Welcome to Wordle!                   |',
      '|                                                        |',
      '----------------------------------------------------------',
    ].each{|s| UI.padded_puts(s)}
    for guess in 1..6
      check_for_problematic_patterns(d) if guess >= 3
      show_main_menu = true
      while true do
        choice = UI.main_menu(guess, d, show_menu: show_main_menu)
        show_main_menu = false
        case choice
        when 'c'
          UI.print_remaining_count(d)
        when 'p', 'pa'
          UI.print_remaining_words(d, choice == 'p' ? 30 : nil)
        when 'hint'
          Commands::hint(d)
          show_main_menu = true
        when 'q'
          puts ''
          return
        when 'penultimate'
          Commands::penultimate(d)
          show_main_menu = true
        when 'twitter'
          query_result = Twitter::Query::regular
          query_result.print_report
          stats_hash = query_result.stats_hash
          UI.print_remaining_count(d)
          if UI.maybe_filter_twitter(d, stats_hash)
            UI.maybe_absence_of_evidence(d, stats_hash)
          end
          show_main_menu = true
        when 'test'
          dictionary_dot_com_level
        when 'pick a profession'
          Commands::pick_a_profession
        when 'pick a profession simple'
          Commands::pick_a_profession_simple
        when 'pick a profession hard'
          Commands::pick_a_profession_hard
        when 'profession test'
          Commands::pick_a_profession_hard_test
        when 'dad'
          print_a_dad_joke
        when 'generate-fingerprints'
          puts 'Generating fingerprints takes a long time (~20 min).'
          puts 'Typically it is only necessary after re-scraping of NYT,'
          puts 'or if building support for a new fingerprint file.'
          if UI.prompt_for_input("Type 'I understand' to proceed") == 'I understand'
            Fingerprint::regenerate_compress_and_save('REPLACE_ME')
          else
            puts 'Fingerprint generation skipped'
          end
          show_main_menu = true
        when 'fingerprint-analysis'
          query_result = Twitter::Query::regular
          query_result.print_report
          stats_hash = query_result.stats_hash
          Fingerprint::fingerprint_analysis(d, stats_hash)
          show_main_menu = true
        when 'fingerprint-analysis --verbose'
          verbose_number = UI.prompt_for_numeric_input('Enter number to show in verbose mode:')
          query_result = Twitter::Query::regular
          query_result.print_report
          stats_hash = query_result.stats_hash
          Fingerprint::fingerprint_analysis(d, stats_hash, verbose: verbose_number)
          show_main_menu = true
        when 'solver'
          Commands::full_solver(d)
          show_main_menu = true
        when 'give me the answer'
          Commands::give_me_the_answer(d)
        when 'gmta1'
          Commands::give_me_the_answer_1(d)
        when 'gmta2'
          Commands::give_me_the_answer_2(d)
        when 'performance'
          sw = Stopwatch.new
          # time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          # (0...100).each {|_| Filter::filter_4g(populate_all_words, 2, 1)}
          # (0...100).each {|_| Filter::filter_3g1y(populate_all_words, 1, 2)}
          (0...100).each {|i| Filter::filter_3g2y(populate_all_words, 1, 2)}
          # (0...1).each {|_| Filter::filter_2g3y_v3(populate_all_words, 1, 2)}
          # (0...5).each {|_| Filter::filter_2g3y_v2(populate_all_words, 1, 2); puts "#{i}: #{sw.elapsed_time}"}
          # (0...5).each {|i| Filter::filter_2g3y_v1(populate_all_words, 1, 2); puts "#{i}: #{sw.elapsed_time}"}
          # (0...5).each {|_| Filter::filter_1g4y(populate_all_words, 1); puts "#{i}: #{sw.elapsed_time}"}
          # (0...3).each {|_| Filter::filter_0g5y(populate_all_words); puts "#{i}: #{sw.elapsed_time}"}
          puts sw.elapsed_time
          show_main_menu = true
        when 'regression'
          Commands::regression_analysis(d)
          show_main_menu = true
        when 'goofball'
          Commands::goofball_analysis
        when 'help', 'h'
          UI.print_usage
        when '' # pressing enter shouldn't cause "unrecognized input"
        else
          if choice.length == 5
            response = UI.prompt_for_input('Enter the response (!?-):')
            Filter::filter(d, choice, response)
            break
          else
            Alert.alert "unrecognized input (#{choice})"
          end
        end
      end
    end
  end

  def self.maybe_absence_of_evidence(d, stats_hash)
    UI::padded_puts ''
    if 'y' == UI.prompt_for_input('Would you like to make deductions based on absence of evidence? (y/n)')
      Commands::penultimate_twitter_absence_of_evidence(d, stats_hash)
    end
  end

  def self.maybe_filter_twitter(d, stats_hash)
    if 'y' == choice = UI.prompt_for_input('Would you like to proceed with filtering? (y/n)', prompt_on_new_line: true)
      choice2 = UI.prompt_for_input(
        "There are #{d.size} words remaining. Would you like to see filtering output? (y/n)",
        prompt_on_new_line: true)
      previous_maybe = Debug.maybe?
      Debug.set_maybe(choice2 == 'y')
      Commands::filter_twitter(d, stats_hash)
      Debug.set_maybe(previous_maybe)
    end
    # caller needs to know whether filtering was done
    choice == 'y'
  end

  def self.print_remaining_words(d, max_print = nil)
    # route
    # pride (Alert! Wordle 30 answer!)
    # prize
    d.each_with_index do |(word, _value), index|
      break if max_print && index >= max_print
      UI::padded_puts "#{word}#{PreviousWordleSolutions.maybe_alert_string(word)}"
    end
    UI::padded_puts "skipping #{d.size-max_print} additional results..." if max_print && d.size > max_print
  end

  def self.print_usage
    [
      '',
      '.----------------------------------------------.',
      '|                                              |',
      '|                     Usage                    |',
      '|                                              |',
      '\----------------------------------------------/',
      'c                  : count',
      'p                  : print',
      'pa                 : print all',
      'hint               : hint',
      'q                  : quit',
      '',
      'twitter            : run Twitter analysis',
      'goofball           : run goofball analysis (look for impossible tweet authors)',
      'solver             : run (interactive) solver',
      'give me the answer : find top-scoring word and print',
      '',
      'dad                : print a dad joke',
      'help, h            : print this message',
      '',
    ].each{|s| UI::padded_puts(s)}
  end

  def self.print_remaining_count(d)
    UI::padded_puts remaining_count_string d
  end

  def self.remaining_count_string(d)
    "There #{d.length==1?'is':'are'} #{d.size} word#{d.length==1?'':'s'} remaining."
  end
end

Tests::run_tests
d = populate_all_words
UI.play(d)
