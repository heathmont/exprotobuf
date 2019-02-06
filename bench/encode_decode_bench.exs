defmodule Exprotobuf.EncodeDecodeBench do
  use Benchfella
  alias Exprotobuf.Bench.Proto.Wrappers.Msg

  @msg %Msg{
    double_scalar: 0.0,
    float_scalar: 0.0,
    int64_scalar: 0,
    uint64_scalar: 0,
    int32_scalar: 0,
    uint32_scalar: 0,
    bool_scalar: false,
    string_scalar: "",
    bytes_scalar: "",
    os_scalar: :LINUX,
    double_value: nil,
    float_value: nil,
    int64_value: nil,
    uint64_value: nil,
    int32_value: nil,
    uint32_value: nil,
    bool_value: nil,
    string_value: nil,
    bytes_value: nil,
    os_value: nil,
    oneof_payload: nil
  }

  @encoded_msg @msg
               |> Msg.encode()

  bench "encode" do
    @msg
    |> Msg.encode()
  end

  bench "decode" do
    @encoded_msg
    |> Msg.decode()
  end
end
