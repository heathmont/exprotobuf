defmodule Exprotobuf.EncodeDecodeBench do
  use Benchfella
  alias Exprotobuf.Bench.Proto.Recursive.Msg
  alias Exprotobuf.Bench.Proto.Helper

  @msg0 Helper.msg(0)
  @msg10 Helper.msg(10)
  @msg50 Helper.msg(50)
  @msg100 Helper.msg(100)

  @encoded_msg0 Helper.msg(0) |> Msg.encode()
  @encoded_msg10 Helper.msg(10) |> Msg.encode()
  @encoded_msg50 Helper.msg(50) |> Msg.encode()
  @encoded_msg100 Helper.msg(100) |> Msg.encode()

  bench "encode 0" do
    @msg0
    |> Msg.encode()
  end

  bench "encode 10" do
    @msg10
    |> Msg.encode()
  end

  bench "encode 50" do
    @msg50
    |> Msg.encode()
  end

  bench "encode 100" do
    @msg100
    |> Msg.encode()
  end

  bench "decode 0" do
    @encoded_msg0
    |> Msg.decode()
  end

  bench "decode 10" do
    @encoded_msg10
    |> Msg.decode()
  end

  bench "decode 50" do
    @encoded_msg50
    |> Msg.decode()
  end

  bench "decode 100" do
    @encoded_msg100
    |> Msg.decode()
  end
end
