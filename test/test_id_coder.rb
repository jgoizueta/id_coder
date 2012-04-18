require 'helper'

class TestIdCoder < Test::Unit::TestCase

  def setup
    @id_coder = IdCoder[
      :num_digits => 6,
      :block_digits => 2,
      :check_digit => true
    ]
  end

  def test_bijectivity
    # sanity check
    assert@id_coder.check_digit?
    assert_equal 6,@id_coder.num_digits
    assert_equal 2,@id_coder.block_digits
    assert_equal 7,@id_coder.code_length
    assert_equal 32, IdCoder::RADIX
    assert_equal 32**6,@id_coder.num_valid_codes

    # Test numbers within the basic range (num_digits)
    test_numbers = (0..100).to_a + (99999900..100000020).to_a + [232211,9898774,1002,343332,1023,1024,1025]
    test_numbers.each do |number|
      code =@id_coder.id_to_code(number)
      assert_equal 7, code.size # test also code length here
      assert_equal number,@id_coder.code_to_id(code),"#{number} is converted to a code and back"
    end

    # Test larger numbers
    test_numbers = (1_999_999_990..2_000_000_010).to_a + (1_999_999_999_990..2_000_000_000_010).to_a
    test_numbers.each do |number|
      code =@id_coder.id_to_code(number)
      assert code.size > 7
      assert(
        (code.size-(@id_coder.check_digit? ? 1 : 0)-@id_coder.num_digits)%@id_coder.block_digits == 0
      )
      assert_equal number,@id_coder.code_to_id(code),"#{number} is converted to a code and back"
    end

  end

  def test_invalid_numbers
    # sanity check
    assert@id_coder.check_digit?
    assert_equal 6,@id_coder.num_digits
    assert_equal 2,@id_coder.block_digits
    assert_equal 7,@id_coder.code_length
    assert_equal 32, IdCoder::RADIX
    assert_equal 32**6,@id_coder.num_valid_codes
    # => ~1000000000 codes

    assert_raise(IdCoder::InvalidNumber){@id_coder.id_to_code("1") }
    assert_raise(IdCoder::InvalidNumber){@id_coder.id_to_code(-1) }
    assert_nothing_raised(IdCoder::InvalidNumber){@id_coder.id_to_code(2000000000) }
    assert_nothing_raised(IdCoder::InvalidNumber){@id_coder.id_to_code(0) }
    assert_nothing_raised(IdCoder::InvalidNumber){@id_coder.id_to_code(1) }
    assert_nothing_raised(IdCoder::InvalidNumber){@id_coder.id_to_code(100) }
    assert_nothing_raised(IdCoder::InvalidNumber){@id_coder.id_to_code(1000000000) }
    assert_nothing_raised(IdCoder::InvalidNumber){@id_coder.id_to_code(2000000000) }
    assert_nothing_raised(IdCoder::InvalidNumber){@id_coder.id_to_code(100000000000000000000) }
  end

  def test_invalid_codes
    @id_coder = IdCoder[:num_digits=>4, :block_digits=>3, :check_digit=>false]
    # sanity check
    assert !@id_coder.check_digit?
    assert_equal 4,@id_coder.num_digits
    assert_equal 3,@id_coder.block_digits
    assert_equal 4,@id_coder.code_length
    assert_equal 32, IdCoder::RADIX
    assert_equal 32**4,@id_coder.num_valid_codes

    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(1023) }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(234) }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(2345) }
    assert_nothing_raised(IdCoder::InvalidCode){@id_coder.code_to_id('2345') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('345') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('34567') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('3415') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('34I5') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('2A04') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('2AO4') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('2A-3') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('2A 3') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('2A)3') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('345678') }
    assert_nothing_raised(IdCoder::InvalidCode){@id_coder.code_to_id('3456789') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('3456789A') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('3456789AB') }
    assert_nothing_raised(IdCoder::InvalidCode){@id_coder.code_to_id('3456789ABC') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('3456789ABCD') }
    assert_nothing_raised(IdCoder::InvalidCode){@id_coder.code_to_id('2A45') }
    assert_nothing_raised(IdCoder::InvalidCode){@id_coder.code_to_id(' 2A43  ') }
    assert_nothing_raised(IdCoder::InvalidCode){@id_coder.code_to_id('2a43') }
  end

  def test_check_digits
    # sanity check
    assert@id_coder.check_digit?
    assert_equal 6,@id_coder.num_digits
    assert_equal 2,@id_coder.block_digits
    assert_equal 7,@id_coder.code_length
    assert_equal 32, IdCoder::RADIX
    assert_equal 32**6,@id_coder.num_valid_codes

    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(1023) }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(234) }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(2345938) }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('2345938') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('345432') }
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id('3454321') }
    valid_code =@id_coder.id_to_code(234331)
    assert_equal 7, valid_code.size
    digits = %w{2 3 4 5 6 7 8 9 A B C D E F G H J K L M N P Q R S T U V W X Y Z}
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(valid_code[0...-1])}
    # Check that changing the check digit makes the code invalid
    digits.each do |digit|
      next if digit == valid_code[-1,1]
      assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(valid_code[0...-1]+digit)}
    end
    # Check that any single-digit change makes the code invalid
    (0..5).each do |i|
      digits.each do |digit|
        next if digit == valid_code[i,1]
        invalid_code = valid_code[0,i] + digit + valid_code[i+1..-1]
        assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(invalid_code)}
      end
    end
    # Check that adjacent digit swapping makes the code invalid
    # (there are some exceptions though, see http://en.wikipedia.org/wiki/Luhn_mod_N_algorithm)
    # TODO: sistematic check avoiding exceptions
    invalid_code = valid_code[0,2] + valid_code[3,1] + valid_code[2,1] + valid_code[4..-1]
    assert_raise(IdCoder::InvalidCode){@id_coder.code_to_id(invalid_code)}
  end

  def test_internal_sanity
    # Check the coded digits used: must be exactly IdCoder::RADIX unique uppercase characters
    chars = []
    IdCoder::CODE_DIGITS.each_byte{|b| chars << b.chr}
    assert_equal IdCoder::RADIX, chars.uniq.size
    assert_equal IdCoder::CODE_DIGITS.upcase, IdCoder::CODE_DIGITS

    # Check the internally-used radix-32 digits to be consistent with Integer#to_s
    assert_equal IdCoder::RADIX, IdCoder::DIGITS.size
    (0...IdCoder::RADIX).each do |i|
      assert_equal i.to_s(IdCoder::RADIX), IdCoder::DIGITS[i,1]
    end
  end


end