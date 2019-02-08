defmodule Protobuf.Const do
  defmacro max_int32 do
    2_147_483_647
  end

  defmacro min_int32 do
    -2_147_483_648
  end

  defmacro max_int64 do
    9_223_372_036_854_775_807
  end

  defmacro min_int64 do
    -9_223_372_036_854_775_808
  end

  defmacro max_uint32 do
    4_294_967_295
  end

  defmacro min_uint32 do
    0
  end

  defmacro max_uint64 do
    18_446_744_073_709_551_615
  end

  defmacro min_uint64 do
    0
  end
end
