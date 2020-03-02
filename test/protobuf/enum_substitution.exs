defmodule Protobuf.EnumSubstitution.Test do
  use Protobuf.Case

  defmodule Proto do
    use Protobuf, from: Path.expand("../proto/enum_substitution.proto", __DIR__)
  end

  alias Proto.MsgHello
  alias Proto.MsgWorld

  test "Hello and World are binary compatible" do
    require Proto.Hello.Hello, as: Hello
    require Proto.World.World, as: World

    left =
      %MsgHello{
        int64: 42,
        hello: Hello.atoms() |> List.last(),
        string: "bar"
      }
      |> MsgHello.encode()

    right =
      %MsgWorld{
        int64: 42,
        world: World.atoms() |> List.last(),
        string: "bar"
      }
      |> MsgWorld.encode()

    assert left == right
  end
end
