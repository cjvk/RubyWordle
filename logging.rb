#!/usr/bin/ruby -w

class Stopwatch
  def initialize
    @time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
  def lap
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - @time_start
  end
  def elapsed_time
    "elapsed_time: #{'%.1f' % lap} seconds"
  end
end

class String
  def pad_right_to_length(desired_length, termination_character: ' ')
    termination_character = ' ' if termination_character.length != 1
    self + ' ' * [(desired_length-self.length-1), 0].max + termination_character
  end
end

module UI
  @@suppress_all_output = false
  def UI::suppress_on
    @@suppress_all_output = true
  end
  def UI::suppress_off
    @@suppress_all_output = false
  end
  def UI::suppress_all_output?
    @@suppress_all_output
  end

  LEFT_PADDING_DEFAULT = 20
  def UI::padded_puts(s)
    print ' ' * LEFT_PADDING_DEFAULT if s.length > 0 && !suppress_all_output?
    puts s if !suppress_all_output?
  end

  def UI::padded_print(s)
    print "#{' ' * LEFT_PADDING_DEFAULT}#{s}" if !suppress_all_output?
  end

  def self.prompt_for_input(input_string, prompt_on_new_line: false, valid_entries: nil)
    padded_puts input_string if prompt_on_new_line
    while [padded_print(prompt_on_new_line ? '==> ' : "#{input_string} ==> ")]
      .map{|_| gets.chomp}
      .map{|input| exit if ['exit', 'quit'].include? input; input}
      .map{|input| return input if !valid_entries || valid_entries.include?(input); input}
    end
  end

  def self.prompt_for_numeric_input(input_string, prompt_on_new_line: false, default_value: nil)
    padded_puts input_string if prompt_on_new_line
    while true
      padded_print prompt_on_new_line ? '==> ' : "#{input_string} ==> "
      user_input = [gets.chomp]
        .map{|input| exit if input == 'exit' || input == 'quit'; input}
        .map{|input| input!='' && input==input.to_i.to_s ? input.to_i : default_value}[0]
      return user_input if user_input != nil
    end
  end
end

module Alert
  def self.alert(s)
    puts "ALERT: #{s}" if !UI::suppress_all_output?
  end
  def self.warn(s)
    puts "WARN: #{s}" if !UI::suppress_all_output?
  end
end

module Debug
  LOG_LEVEL_NONE = 0
  LOG_LEVEL_TERSE = 1
  LOG_LEVEL_NORMAL = 2
  LOG_LEVEL_VERBOSE = 3

  THRESHOLD = LOG_LEVEL_NORMAL

  module Internal
    @@log_level_to_string = {
      LOG_LEVEL_NONE => 'none',
      LOG_LEVEL_TERSE => 'TERSE',
      LOG_LEVEL_NORMAL => 'NORMAL',
      LOG_LEVEL_VERBOSE => 'VERBOSE',
    }
    def Internal::println(s, log_level)
      puts s if log_level <= THRESHOLD && !UI::suppress_all_output?
    end
    def Internal::decorate(s, log_level)
      "debug(#{@@log_level_to_string[log_level]}): #{s}"
    end
    def Internal::decorate_and_print(s, log_level)
      Internal::println(Debug::Internal::decorate(s, log_level), log_level)
    end
  end

  def self.log_terse(s)
    Debug::Internal::decorate_and_print(s, LOG_LEVEL_TERSE)
  end
  def self.log(s)
    Debug::Internal::decorate_and_print(s, LOG_LEVEL_NORMAL)
  end
  def self.log_verbose(s)
    Debug::Internal::decorate_and_print(s, LOG_LEVEL_VERBOSE)
  end

  @@maybe_log = false

  def self.set_maybe(b)
    @@maybe_log = b
  end
  def self.maybe?
    @@maybe_log
  end
  def self.set_maybe_false
    @@maybe_log = false
  end
  def self.maybe_log_terse(s)
    Debug.log_terse s if @@maybe_log
  end
  def self.maybe_log(s)
    Debug.log s if @@maybe_log
  end
  def self.maybe_log_verbose(s)
    Debug.log_verbose s if @@maybe_log
  end
end

