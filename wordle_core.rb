#!/usr/bin/ruby -w

module WordleShareColors
  # Normal mode
  # e.g. https://twitter.com/mobanwar/status/1552908148696129536
  GREEN = "\u{1F7E9}"
  YELLOW = "\u{1F7E8}"
  WHITE = "\u{2B1C}"
  NORMAL_MODE_PATTERN = /[#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}]/

  # Dark mode
  # https://twitter.com/SLW551505/status/1552871344680886278
  # green and yellow as before, but black instead of white
  BLACK = "\u{2B1B}"
  DARK_MODE_PATTERN = /[#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}]/

  # name: Decided on "Deborah mode"
  # https://twitter.com/DeborahDtfpress/status/1552860375602778112
  # white   => white
  # yellow  => blue
  # green   => orange
  BLUE = "\u{1F7E6}"
  ORANGE = "\u{1F7E7}"
  DEBORAH_MODE_PATTERN = /[#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}]/

  # "Deborah-dark" mode
  # https://twitter.com/sandraschulze/status/1552673827766689792
  # white   => black
  # yellow  => blue
  # green   => orange
  DEBORAH_DARK_MODE_PATTERN = /[#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}]/

  # Other useful patterns
  ANY_WORDLE_SQUARE = /[#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}]/
  ANY_WORDLE_SQUARE_PLUS_NEWLINE = /[#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}\n]/
  NON_WORDLE_CHARACTERS = /[^#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}\n]/
end

module WordleModes
  NORMAL_MODE = 'Normal'
  DARK_MODE = 'Dark'
  DEBORAH_MODE = 'Deborah'
  DEBORAH_DARK_MODE = 'DeborahDark'
  UNKNOWN_MODE = 'Unknown'

  def self.determine_mode(text)
    # This would typically be called if text is "probably a wordle post"
    if text.include?(WordleShareColors::ORANGE) || text.include?(WordleShareColors::BLUE)
      if text.include? WordleShareColors::BLACK
        mode = DEBORAH_DARK_MODE
      else
        mode = DEBORAH_MODE
      end
    elsif text.include?(WordleShareColors::GREEN) || text.include?(WordleShareColors::YELLOW)
      if text.include? WordleShareColors::BLACK
        mode = DARK_MODE
      else
        mode = NORMAL_MODE
      end
    else
      mode = UNKNOWN_MODE
    end
    mode
  end

  MODES_TO_PATTERNS = [
    [NORMAL_MODE, WordleShareColors::NORMAL_MODE_PATTERN],
    [DARK_MODE, WordleShareColors::DARK_MODE_PATTERN],
    [DEBORAH_MODE, WordleShareColors::DEBORAH_MODE_PATTERN],
    [DEBORAH_DARK_MODE, WordleShareColors::DEBORAH_DARK_MODE_PATTERN],
  ].to_h
  def self.mode_to_pattern(mode)
    MODES_TO_PATTERNS[mode]
  end

  UNICODES_TO_NORMALIZED_STRINGS = {
    NORMAL_MODE => { # not sure why but '=>' works, but ':' does not
      WordleShareColors::WHITE => 'w',
      WordleShareColors::YELLOW => 'y',
      WordleShareColors::GREEN => 'g',
    },
    DARK_MODE => {
      WordleShareColors::BLACK => 'w',
      WordleShareColors::YELLOW => 'y',
      WordleShareColors::GREEN => 'g',
    },
    DEBORAH_MODE => {
      WordleShareColors::WHITE => 'w',
      WordleShareColors::BLUE => 'y',
      WordleShareColors::ORANGE => 'g',
    },
    DEBORAH_DARK_MODE => {
      WordleShareColors::BLACK => 'w',
      WordleShareColors::BLUE => 'y',
      WordleShareColors::ORANGE => 'g',
    },
  }
  def self.unicode_to_normalized_string(unicode_string, mode)
    UNICODES_TO_NORMALIZED_STRINGS[mode][unicode_string]
  end
end

module InterestingWordleResponses
  WORDLE_4G   = 1
  WORDLE_3G1Y = 2
  WORDLE_3G2Y = 3
  WORDLE_2G3Y = 4
  WORDLE_1G4Y = 5
  WORDLE_0G5Y = 6
  NOT_INTERESTING = 7

  def InterestingWordleResponses::num_with_color(color, word)
    num_with_color = 0
    (0...5).each { |i| num_with_color += 1 if word[i] == color }
    num_with_color
  end

  def InterestingWordleResponses::determine_interestingness(wordle_response)
    # wordle_response is a 5-character string normalized to g/y/w
    # e.g. "ygwyy" for a guess of saner and a wordle of raise
    num_g = num_with_color('g', wordle_response)
    num_y = num_with_color('y', wordle_response)
    num_w = num_with_color('w', wordle_response)
    return InterestingWordleResponses::WORDLE_4G if num_g == 4 && num_w == 1
    return InterestingWordleResponses::WORDLE_3G1Y if num_g == 3 && num_y == 1
    return InterestingWordleResponses::WORDLE_3G2Y if num_g == 3 && num_y == 2
    return InterestingWordleResponses::WORDLE_2G3Y if num_g == 2 && num_y == 3
    return InterestingWordleResponses::WORDLE_1G4Y if num_g == 1 && num_y == 4
    return InterestingWordleResponses::WORDLE_0G5Y if num_g == 0 && num_y == 5
    return InterestingWordleResponses::NOT_INTERESTING
  end

  def InterestingWordleResponses::calculate_name_subname_key(wordle_response, interestingness, count=0)
    case interestingness
    when InterestingWordleResponses::WORDLE_4G
      name = '4g'
      subname = "#{wordle_response.index('w')+1}.#{count}"
    when InterestingWordleResponses::WORDLE_3G1Y
      name = '3g1y'
      subname = "yellow#{wordle_response.index('y')+1}.white#{wordle_response.index('w')+1}"
    when InterestingWordleResponses::WORDLE_3G2Y
      name = '3g2y'
      y1 = wordle_response.index('y')
      y2 = wordle_response.index('y', y1+1)
      subname = "yellow#{y1+1}#{y2+1}"
    when InterestingWordleResponses::WORDLE_2G3Y
      name = '2g3y'
      g1 = wordle_response.index('g')
      g2 = wordle_response.index('g', g1+1)
      subname = "green#{g1+1}#{g2+1}"
    when InterestingWordleResponses::WORDLE_1G4Y
      name = '1g4y'
      g = wordle_response.index('g')
      subname = "green#{g+1}"
    when InterestingWordleResponses::WORDLE_0G5Y
      name = '0g5y'
      subname = ''
    when InterestingWordleResponses::NOT_INTERESTING
      raise "Error: NOT_INTERESTING sent to calculate_name_subname_key"
    else
      raise "Error: unknown interestingness"
    end
    key = "#{name}.#{subname}"
    return name, subname, key
  end
end

def close(w1, w2)
  diff = 0
  (0...5).each {|i| diff += (w1[i]==w2[i] ? 0 : 1)}
  diff == 1
end

def check_for_problematic_patterns(d)
  # e.g. Wordle 265 ("watch"), after raise-clout (-!---, ?---?)
  # legal words remaining: watch, match, hatch, patch, batch, natch, tacky
  # 6 words with _atch, plus tacky
  pp_dict = {}
  d.each do |key1, _value1|
    break if Twitter::Configuration.instrumentation_only
    found = false
    pp_dict.each do |key2, value2|
      if close(key1, key2)
        found = true
        pp_dict[key2] = value2 + 1
      end
    end
    pp_dict[key1] = 1 if !found
  end
  if Twitter::Configuration.instrumentation_only
    Debug.log 'skipped problematic pattern loop, using hardcoded result'
    pp_dict = {'hilly': 3, 'floss': 10} if Twitter::Configuration.instrumentation_only
  end
  UI::padded_puts 'Checking for problematic patterns...'
  pp_dict.each do |key, value|
    if value > 2
      puts ''
      UI::padded_puts 'PROBLEMATIC PATTERN ALERT'
      UI::padded_puts "Found \"#{key}\" with #{value} matching words (print for details)"
      puts ''
      puts ''
    end
  end
  UI::padded_puts 'No problematic patterns found!' if pp_dict.values.max <= 2
end
