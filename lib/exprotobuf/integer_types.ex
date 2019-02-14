defmodule Protobuf.IntegerTypes do
  @min_int32 -2_147_483_648
  @max_int32 2_147_483_647

  defmacro min_int32 do
    @min_int32
  end

  defmacro max_int32 do
    @max_int32
  end

  defmacro is_int32(some) do
    quote do
      is_integer(unquote(some)) and unquote(some) >= unquote(@min_int32) and
        unquote(some) <= unquote(@max_int32)
    end
  end

  @min_int64 -9_223_372_036_854_775_808
  @max_int64 9_223_372_036_854_775_807

  defmacro min_int64 do
    @min_int64
  end

  defmacro max_int64 do
    @max_int64
  end

  defmacro is_int64(some) do
    quote do
      is_integer(unquote(some)) and unquote(some) >= unquote(@min_int64) and
        unquote(some) <= unquote(@max_int64)
    end
  end

  @min_uint32 0
  @max_uint32 4_294_967_295

  defmacro min_uint32 do
    @min_uint32
  end

  defmacro max_uint32 do
    @max_uint32
  end

  defmacro is_uint32(some) do
    quote do
      is_integer(unquote(some)) and unquote(some) >= unquote(@min_uint32) and
        unquote(some) <= unquote(@max_uint32)
    end
  end

  @min_uint64 0
  @max_uint64 18_446_744_073_709_551_615

  defmacro min_uint64 do
    @min_uint64
  end

  defmacro max_uint64 do
    @max_uint64
  end

  defmacro is_uint64(some) do
    quote do
      is_integer(unquote(some)) and unquote(some) >= unquote(@min_uint64) and
        unquote(some) <= unquote(@max_uint64)
    end
  end
end
