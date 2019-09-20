defmodule Protobuf.OverflowTest do
  defmodule Schema do
    use Protobuf, """
    syntax = "proto3";
    message Msg {
      int32 int32 = 1;
      int64 int64 = 2;
      uint32 uint32 = 3;
      uint64 uint64 = 4;
    }
    """
  end

  use Protobuf.Case
  require Protobuf.IntegerTypes, as: IntegerTypes
  alias Schema.Msg

  @int_types [:int32, :int64, :uint32, :uint64]

  @int_types
  |> Enum.each(fn type ->
    pattern = fn expression ->
      {
        :%,
        [],
        [
          {:__aliases__, [alias: false], [:Protobuf, :OverflowTest, :Schema, :Msg]},
          {:%{}, [], Enum.map(@int_types, &{&1, &1 == type && expression || 0})}
        ]
      }
    end

    {max, []} =
      quote do
        IntegerTypes.unquote("max_#{type}" |> String.to_atom())
      end
      |> Code.eval_quoted([], __ENV__)

    {min, []} =
      quote do
        IntegerTypes.unquote("min_#{type}" |> String.to_atom())
      end
      |> Code.eval_quoted([], __ENV__)

    test "max #{type}" do
      assert unquote(pattern.(max)) =
               unquote(pattern.(max))
               |> Msg.encode()
               |> Msg.decode()
    end

    test "max #{type} overflow" do
      assert_raise RuntimeError,
                   ~r/^can not encode value #{unquote(max + 1)} as field %Protobuf.Field{.+} because of type overflow$/,
                   fn ->
                     unquote(pattern.(max + 1))
                     |> Msg.encode()
                     |> Msg.decode()
                   end
    end

    test "min #{type}" do
      assert unquote(pattern.(min)) =
               unquote(pattern.(min))
               |> Msg.encode()
               |> Msg.decode()
    end

    test "min #{type} overflow" do
      assert_raise RuntimeError,
                   ~r/can not encode value #{unquote(min - 1)} as field %Protobuf.Field{.+} because of type overflow$/,
                   fn ->
                     unquote(pattern.(min - 1))
                     |> Msg.encode()
                     |> Msg.decode()
                   end
    end
  end)
end
