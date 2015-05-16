defmodule Entice.Utils.BitOpsTest do
  use ExUnit.Case, async: true
  import Entice.Utils.BitOps


  test "bit at" do
    # in range
    assert 0 == get_bit(0b00010101, 4)
    assert 1 == get_bit(0b00010101, 1)
    assert 0 == get_bit(0b00010101, 8)
    # outta range, mister!
    assert 0 == get_bit(0b00010101, 9)
    assert 0 == get_bit(0b00010101, 42)
  end


  test "bit set" do
    # in range
    assert 0b00001000 == set_bit(0b00000000, 4)
    assert 0b01101001 == set_bit(0b01001001, 6)
    # outta range
    assert 0b10001101001 == set_bit(0b01101001, 11)
  end


  test "bit unset" do
    # in range
    assert 0b00000000 == unset_bit(0b00001000, 4)
    # outta range
    assert 0b01101001 == unset_bit(0b01101001, 9)
  end
end
