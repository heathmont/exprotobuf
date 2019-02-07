defmodule Exprotobuf.Bench.Proto do
  use Protobuf,
    use_package_names: true,
    from: Path.expand("../../test/proto/recursive.proto", __DIR__)
end

defmodule Exprotobuf.Bench.Proto.Helper do
  alias Exprotobuf.Bench.Proto.Recursive.Msg
  def msg(depth \\ 0)

  def msg(0) do
    %Msg{
      hello: "hello",
      either: {:world, "world"}
    }
  end

  def msg(depth) when is_integer(depth) and depth > 0 do
    %Msg{
      hello: "hello#{depth}",
      either: {:msg, msg(depth - 1)}
    }
  end
end
