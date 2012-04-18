require 'rubygems'
require 'modalsupport'
require 'modalsettings'

# Id-codes are relatively short codes to represent externally id internal numbers.
#
# A bijection between ids and codes is used to assure uniqueness of codes and to avoid storing the
# codes in the database (codes and ids are computed on-the-fly from each other).
#
# Codes are user-visible; they're designed to be the user's identification of some element.
#
# Only digits an capital letters are used for the codes, excluding I,O,1,0 to avoid confusion,
# and a check digit can be used to detect most common transcription errors. This makes codes
# viable to be transmitted orally, etc.
#
# The number of digits used is scalable: the minimum number of digits and the increment-size can be
# parameterized to render good-looking codes.
#
# An IdCoder can be defined passing to it three optional parameters that define the lenght of the codes:
#   IdCoder[:num_digits=>4, :block_digits=>3, :check_digit=>false]
# An additional parameter can be passed to define which characters will be used as digits for the codes
# and its order; this must be a String of IdCoder::RADIX distinct characters:
#   IdCoder[:code_digits=>"0123456789ABCDEFGHIJKLMNOPQRSTUV"]
# Alternatively, a seed parameter can be passed to generate a randomized string
#   IdCoder[:seed=>8734112]
# Since this might produce different results in different Ruby versions, the code_digits produced can be accessed
# and kept for portability:
#   IdCoder[:seed=>8734112].code_digits # -> "9GTFNJSZA6LQWXV3BEKHYMP75U8R24CD"
#
class IdCoder

  # Internal parameters
  RADIX = 32
  DIGITS = "0123456789abcdefghijklmnopqrstuv"      # RADIX-digits used by Integer#to_s(RADIX), String#to_i(RADIX)
  CODE_DIGITS = "BAFTQ4EJCNVYZKDPG37H5S8WML692RXU" # RADIX-digits used for the codes (permutation of 2-9,A-Z except I,O)

  class InvalidCode < RuntimeError; end
  class InvalidNumber < RuntimeError; end
  class InvalidCodeDigits < RuntimeError; end

  def initialize(config={})
    config = Settings[config]
    if config.code_digits
      @code_digits = config.code_digits
      raise InvalidCodeDigits, "Invalid digits" if @code_digits.bytes.to_a.uniq.size!=RADIX
    else
      @code_digits = CODE_DIGITS
      if config.seed
        srand config.seed
        @code_digits = @code_digits.bytes.to_a.shuffle.map(&:chr)*""
      end
    end
    @num_digits = (config.num_digits || 6).to_i
    @block_digits = (config.block_digits || 2).to_i
    @check_digit = config.check_digit
    @check_digit = true if @check_digit.nil?
  end

  include ModalSupport::BracketConstructor

  include

  # configurable parameters

  # Minumum number of digits used; limits the number of valid ids before scaling up to RADIX**num_digits
  def num_digits
    @num_digits
  end

  # Use a check digit?: this increases the length of codes in one
  def check_digit?
    @check_digit
  end

  # Number of digits for incremental scaling-up blocks
  def block_digits
    @block_digits
  end

  # Properties of the codes

  # mininum code_length
  def code_length
    num_digits + (check_digit? ? 1 : 0)
  end

  # Number of valid codes before scaling-up
  def num_valid_codes
    RADIX**num_digits
  end

  def num_digits_for(id)
    if id<num_valid_codes
      num_digits
    else
      # ((Math.log(id)/Math.log(RADIX)-code_length)/block_digits).ceil*block_digits + num_digits
      nd = num_digits
      loop do
        nd += block_digits
        nvc = RADIX**nd
        break if id<nvc
      end
      # check = ((Math.log(id)/Math.log(RADIX)-code_length)/block_digits).ceil*block_digits + num_digits
      # raise "nd=#{nd}; [#{check}] id=#{id}" unless nd==check
      nd
    end
  end

  def code_length_for(id)
    num_digits_for(id) + (check_digit? ? 1 : 0)
  end

  def code_digits
    @code_digits
  end

  def parameters
    { :num_digits=>@num_digits, :block_digits=>@block_digits, :check_digit=>@check_digit, :code_digits=>@code_digits }
  end

  def inspect
    "IdCoder[#{parameters.inspect.unwrap('[]')}]"
  end

  # Code generatioon

  # Direct encoding: generate an Id-Code from an integer id.
  def id_to_code(id)
    raise InvalidNumber, "Numbers to be coded must be passed as integers" unless id.kind_of?(Integer)
    raise InvalidNumber, "Negative numbers cannot be encoded: #{id}" if id<0
    nd = num_digits_for(id)
    v = id.to_s(RADIX)
    v = "0"*(nd-v.size) + v
    i = 0
    code = ""
    mask = 0
    v.reverse.each_byte do |b|
      d = DIGITS.index(b.chr)
      code << @code_digits[mask = ((d+i)%RADIX ^ mask),1]
      i += 1
    end
    code << check_digit(code) if check_digit?
    code
  end

  # Inverse encoding: compute the integer id for a Id-Code
  def code_to_id(code)
    raise InvalidCode, "Codes must be strings" unless code.kind_of?(String)
    code = code.strip.upcase # tolerate case differences & surrounding whitespace
    raise InvalidCode, "Invalid code: #{code}" unless code =~ /\A[#{@code_digits}]+\Z/
    # raise InvalidCode, "Invalid code length: #{code.size} for #{code} (must be #{code_length})" unless code.size==code_length
    if check_digit?
      cd = code[-1,1]
      code = code[0...-1]
      raise InvalidCode, "Invalid code: #{code+cd}" if cd!=check_digit(code)
    end
    nd = code.size
    sx = nd-num_digits
    raise InvalidCode, "Invalid code length: #{code.size} for #{code}" unless sx>=0 && (sx%block_digits)==0
    i = 0
    v = ""
    mask = 0
    code.each_byte do |b|
      next_mask = @code_digits.index(b.chr)
      d  = ((next_mask ^ mask)-i)%RADIX
      mask = next_mask
      d = DIGITS[d,1]
      v = d + v
      i += 1
    end
    v.to_i(RADIX)
  end

  # Check code: returns true (valid) or false (invalid)
  def valid_code?(code)
    is_valid = true
    begin
      code_to_id(code)
    rescue InvalidCode
      is_valid = false
    end
    is_valid
  end

  private

  # Check digits are computed using the Luhn Mod N Algorithm:
  # http://en.wikipedia.org/wiki/Luhn_mod_N_algorithm
  def check_digit(code)
    factor = 2
    sum = 0
    code.each_byte do |b|
      addend = factor * @code_digits.index(b.chr)
      factor = (factor==2) ? 1 : 2
      addend = (addend / RADIX) + (addend % RADIX)
      sum += addend
    end
    remainder = sum % RADIX
    @code_digits[(RADIX - remainder) % RADIX, 1]
  end


end
