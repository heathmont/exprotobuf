defmodule Protobuf.CustomHooksTest.Decimal do
  defstruct sign: 1,
            coef: 0,
            exp: 0
end

defmodule Protobuf.CustomHooksTest.Schema do
  use Protobuf, """
  syntax = "proto3";

  message Msg {
    string hello = 1;
    Decimal world = 2;

    message Decimal {
      bool negative = 1;
      uint64 coef   = 2;
      int32 exp     = 3;
    }
  }
  """
end

defmodule Protobuf.CustomHooksTest do
  use Protobuf.Case
  alias Protobuf.CustomHooksTest.Decimal
  alias Protobuf.CustomHooksTest.Schema

  defimpl Protobuf.PreEncodable, for: Decimal do
    def pre_encode(%Decimal{sign: sign, coef: coef, exp: exp})
        when sign in [1, -1] and is_integer(coef) and coef >= 0 and is_integer(exp) do
      negative =
        sign
        |> case do
          -1 -> true
          1 -> false
        end

      %Schema.Msg.Decimal{
        negative: negative,
        coef: coef,
        exp: exp
      }
    end
  end

  defimpl Protobuf.PostDecodable, for: Schema.Msg.Decimal do
    def post_decode(%Schema.Msg.Decimal{negative: negative, coef: coef, exp: exp}) do
      sign =
        negative
        |> case do
          true -> -1
          false -> 1
        end

      %Decimal{
        sign: sign,
        coef: coef,
        exp: exp
      }
    end
  end

  @msg %Schema.Msg{
    hello: "hello",
    world: %Decimal{
      sign: -1,
      coef: 123,
      exp: -3
    }
  }

  test "encode" do
    encoded = Schema.Msg.encode(@msg)
    assert is_binary(encoded)
    assert encoded != ""
  end

  test "encode-decode" do
    assert @msg ==
             @msg
             |> Schema.Msg.encode()
             |> Schema.Msg.decode()
  end
end
