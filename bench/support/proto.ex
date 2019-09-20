defmodule Exprotobuf.Bench.Proto do
  use Protobuf,
    use_package_names: true,
    from: Path.expand("../../test/proto/recursive.proto", __DIR__)
end

defmodule Exprotobuf.Bench.Proto.Helper do
  require Exprotobuf.Bench.Proto.Recursive.Msg, as: Msg
  def msg(depth \\ 0)

  def msg(0) do
    %Msg{
      hello: "hello",
      either: {:world, "world"},
      either1: {:world, "world"},
      either2: {:world, "world"},
      either3: {:world, "world"},
      either4: {:world, "world"},
      either5: {:world, "world"},
      either6: {:world, "world"},
      either7: {:world, "world"}
    }
  end

  def msg(depth) when is_integer(depth) and depth > 0 do
    %Msg{
      hello: "hello#{depth}",
      either: {:msg, msg(depth - 1)},
      either1: {:msg, msg(depth - 1)},
      either2: {:msg, msg(depth - 1)},
      either3: {:msg, msg(depth - 1)},
      either4: {:msg, msg(depth - 1)},
      either5: {:msg, msg(depth - 1)},
      either6: {:msg, msg(depth - 1)},
      either7: {:msg, msg(depth - 1)}
    }
  end

  def encode_pure(x) do
    Msg.encode(x)
  end

  def encode_validate(x) do
    :ok = Msg.validate!(x)
    Msg.encode(x)
  end

  def encode_try(x) do
    try do
      Msg.encode(x)
    rescue
      e ->
        :ok = Msg.validate!(x)
        reraise(e, __STACKTRACE__)
    end
  end
end
