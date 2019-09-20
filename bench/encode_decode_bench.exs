defmodule Exprotobuf.EncodeDecodeBench do
  use Benchfella
  alias Exprotobuf.Bench.Proto.Recursive.Msg
  alias Exprotobuf.Bench.Proto.Helper

  @msg0 Helper.msg(0)
  @msg2 Helper.msg(2)
  @msg5 Helper.msg(5)

  @encoded_msg0 Helper.msg(0) |> Msg.encode()
  @encoded_msg2 Helper.msg(2) |> Msg.encode()
  @encoded_msg5 Helper.msg(5) |> Msg.encode()

  bench "encode 0" do
    @msg0
    |> Msg.encode()
  end

  bench "encode 2" do
    @msg2
    |> Msg.encode()
  end

  bench "encode 5" do
    @msg5
    |> Msg.encode()
  end

  bench "decode 0" do
    @encoded_msg0
    |> Msg.decode()
  end

  bench "decode 2" do
    @encoded_msg2
    |> Msg.decode()
  end

  bench "decode 5" do
    @encoded_msg5
    |> Msg.decode()
  end
end
