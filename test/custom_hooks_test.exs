defmodule Protobuf.CustomHooksTest.Decimal do
  defstruct sign: 1,
            coef: 0,
            exp: 0
end

defmodule Protobuf.CustomHooksTest.Schema do
  use Protobuf, """
  syntax = "proto3";

  message Msg {
    Decimal hello  = 1;
    UDecimal world = 2;

    message Decimal {
      bool negative = 1;
      uint64 coef   = 2;
      int32 exp     = 3;
    }

    message UDecimal {
      uint64 coef = 1;
      int32 exp   = 2;
    }
  }

  message Request {
    string name            = 1;
    oneof api {
      string url           = 2;
      ErlangRpc erlang_rpc = 3;
    }

    message ErlangRpc {
      string module_name = 1;
      string node_name   = 2;
    }
  }

  message ContainsPid {
    string name = 1;
    string pid  = 2;
  }
  """
end

defmodule Protobuf.CustomHooksTest do
  use Protobuf.Case
  alias Protobuf.CustomHooksTest.Decimal
  alias Protobuf.CustomHooksTest.Schema
  alias Schema.Request.ErlangRpc
  alias Schema.ContainsPid
  require Schema.Request.OneOf.Api, as: Api

  defimpl Protobuf.PreEncodable, for: Decimal do
    def pre_encode(%Decimal{sign: sign, coef: coef, exp: exp}, Schema.Msg.Decimal)
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

    def pre_encode(%Decimal{sign: 1, coef: coef, exp: exp}, Schema.Msg.UDecimal)
        when is_integer(coef) and coef >= 0 and is_integer(exp) do
      %Schema.Msg.UDecimal{
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

    def post_decoded_type(%Schema.Msg.Decimal{}) do
      quote do
        Protobuf.CustomHooksTest.Decimal.t()
      end
    end
  end

  defimpl Protobuf.PostDecodable, for: Schema.Msg.UDecimal do
    def post_decode(%Schema.Msg.UDecimal{coef: coef, exp: exp}) do
      %Decimal{
        sign: 1,
        coef: coef,
        exp: exp
      }
    end

    def post_decoded_type(%Schema.Msg.UDecimal{}) do
      quote do
        Protobuf.CustomHooksTest.Decimal.t()
      end
    end
  end

  @msg %Schema.Msg{
    hello: %Decimal{
      sign: -1,
      coef: 123,
      exp: -3
    },
    world: %Decimal{
      sign: 1,
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

  defimpl Protobuf.PreEncodable, for: ErlangRpc do
    def pre_encode(%ErlangRpc{module_name: module_name, node_name: node_name}, ErlangRpc) do
      %ErlangRpc{
        module_name: ensure_string(module_name),
        node_name: ensure_string(node_name)
      }
    end

    defp ensure_string(x) when is_atom(x), do: Atom.to_string(x)
    defp ensure_string(x) when is_binary(x), do: x
  end

  defimpl Protobuf.PostDecodable, for: ErlangRpc do
    def post_decode(%ErlangRpc{
          module_name: <<"Elixir.", _::binary>> = module_name,
          node_name: node_name
        })
        when is_binary(node_name) do
      %ErlangRpc{
        module_name: String.to_existing_atom(module_name),
        node_name: String.to_existing_atom(node_name)
      }
    end

    def post_decode(%ErlangRpc{module_name: module_name, node_name: node_name} = erlang_rpc)
        when is_atom(module_name) and is_atom(node_name) do
      erlang_rpc
    end

    def post_decoded_type(%ErlangRpc{}) do
      quote location: :keep do
        %Protobuf.CustomHooksTest.Schema.Request.ErlangRpc{
          module_name: module(),
          node_name: node()
        }
      end
    end
  end

  test "encode-decode oneof" do
    request = %Schema.Request{
      name: "hello",
      api:
        Api.erlang_rpc(%ErlangRpc{
          module_name: __MODULE__,
          node_name: :erlang.node()
        })
    }

    encoded_request = Schema.Request.encode(request)

    pre_encoded_request =
      %Schema.Request{
        request
        | api:
            Api.erlang_rpc(%ErlangRpc{
              module_name: __MODULE__ |> Atom.to_string(),
              node_name: :erlang.node() |> Atom.to_string()
            })
      }
      |> Schema.Request.encode()

    assert is_binary(encoded_request) and encoded_request != ""
    assert encoded_request == pre_encoded_request
    assert request == Schema.Request.decode(encoded_request)
  end

  defimpl Protobuf.PreEncodable, for: ContainsPid do
    def pre_encode(%ContainsPid{pid: x} = message, _) do
      %ContainsPid{message | pid: ensure_binary(x)}
    end

    defp ensure_binary(x) when is_pid(x) do
      x
      |> :erlang.pid_to_list()
      |> :erlang.list_to_binary()
    end

    defp ensure_binary(x) when is_binary(x), do: x
  end

  defimpl Protobuf.PostDecodable, for: ContainsPid do
    def post_decode(%ContainsPid{pid: x} = message) do
      %ContainsPid{message | pid: ensure_pid(x)}
    end

    def post_decoded_type(%ContainsPid{}) do
      quote location: :keep do
        %Protobuf.CustomHooksTest.Schema.ContainsPid{
          name: String.t(),
          pid: pid()
        }
      end
    end

    defp ensure_pid(x) when is_binary(x) do
      x
      |> :erlang.binary_to_list()
      |> :erlang.list_to_pid()
    end

    defp ensure_pid(x) when is_pid(x), do: x
  end

  test "encode-decode ContainsPid" do
    message = %ContainsPid{
      name: "hello",
      pid: self()
    }

    encoded_message = ContainsPid.encode(message)

    assert is_binary(encoded_message) and encoded_message != ""
    assert message == ContainsPid.decode(encoded_message)
  end
end
