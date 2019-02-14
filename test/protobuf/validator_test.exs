defmodule Protobuf.ValidatorTest do
  use Protobuf.Case
  require Protobuf.IntegerTypes, as: IntegerTypes

  defmodule Schema3 do
    use Protobuf, """
    syntax = "proto3";
    message Proto3 {
      double double = 1;
      float float = 2;
      int32 int32 = 3;
      int64 int64 = 4;
      uint32 uint32 = 5;
      uint64 uint64 = 6;
      sint32 sint32 = 7;
      sint64 sint64 = 8;
      fixed32 fixed32 = 9;
      fixed64 fixed64 = 10;
      sfixed32 sfixed32 = 11;
      sfixed64 sfixed64 = 12;
      bool bool = 13;
      string string = 14;
      bytes bytes = 15;

      Enum enum = 16;
      Msg msg = 17;

      oneof either {
        string either_string = 18;
        Msg either_msg = 19;
      }

      enum Enum {
        START = 0;
        STOP  = 1;
      }

      message Msg {
        string key = 1;
        string value = 2;
      }
    }
    """
  end

  alias Schema3.Proto3

  setup do
    %{
      proto3: %Proto3{
        double: -0.5,
        float: -0.5,
        int32: IntegerTypes.max_int32(),
        int64: IntegerTypes.max_int64(),
        uint32: IntegerTypes.max_uint32(),
        uint64: IntegerTypes.max_uint64(),
        sint32: IntegerTypes.max_int32(),
        sint64: IntegerTypes.max_int64(),
        fixed32: IntegerTypes.max_uint32(),
        fixed64: IntegerTypes.max_uint64(),
        sfixed32: IntegerTypes.max_int32(),
        sfixed64: IntegerTypes.max_int64(),
        bool: true,
        string: "hello",
        bytes: <<255, 255, 255>>,
        enum: :START,
        msg: %Proto3.Msg{
          key: "foo",
          value: "bar"
        },
        either: {
          :either_msg,
          %Proto3.Msg{
            key: "foo",
            value: "bar"
          }
        }
      }
    }
  end

  test "proto3 success", %{proto3: %Proto3{} = proto3} do
    import Proto3
    assert :ok = proto3 |> validate
    assert :ok = proto3 |> validate!
  end

  test "proto3 validate! raise", %{proto3: %Proto3{} = proto3} do
    import Proto3
    assert_raise RuntimeError, ~r/^Elixir.Protobuf.ValidatorTest.Schema3.Proto3.t has invalid value 123 of field.+$/, fn ->
      %Proto3{proto3 | float: 123}
      |> validate!
    end
  end

  test "proto3 double + float", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123

    [
      other_erlang_type,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | double: val} |> validate
      assert {:error, _} = %Proto3{proto3 | float: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | double: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | float: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 int32 + sint32 + sfixed32", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_int32() + 1
    neg_overflow = IntegerTypes.min_int32() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | int32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sint32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sfixed32: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | int32: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sint32: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sfixed32: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 int64 + sint64 + sfixed64", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_int64() + 1
    neg_overflow = IntegerTypes.min_int64() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | int64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sint64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sfixed64: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | int64: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sint64: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sfixed64: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 uint32 + fixed32", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_uint32() + 1
    neg_overflow = IntegerTypes.min_uint32() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | uint32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | fixed32: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | uint32: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | fixed32: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 uint64 + fixed64", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_uint64() + 1
    neg_overflow = IntegerTypes.min_uint64() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | uint64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | fixed64: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | uint64: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | fixed64: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 bool", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123

    [
      other_erlang_type,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | bool: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | bool: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 string", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123
    invalid_string = <<255, 255, 255>>

    [
      other_erlang_type,
      invalid_string,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | string: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | string: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 bytes", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123

    [
      other_erlang_type,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | bytes: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | bytes: "hello"} |> validate
    assert :ok = %Proto3{proto3 | bytes: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 enum", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123
    invalid_enum_value = :HELLO

    [
      other_erlang_type,
      invalid_enum_value,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | enum: val} |> validate
    end)

    pos_overflow = IntegerTypes.max_int32() + 1
    neg_overflow = IntegerTypes.min_int32() - 1

    assert {:error, _} =
             %Proto3{proto3 | enum: pos_overflow} |> validate(allow_enum_integer: true)

    assert {:error, _} =
             %Proto3{proto3 | enum: neg_overflow} |> validate(allow_enum_integer: true)

    assert :ok = %Proto3{proto3 | enum: 0} |> validate(allow_enum_integer: true)
    assert :ok = %Proto3{proto3 | enum: 1} |> validate(allow_enum_integer: true)
    assert :ok = %Proto3{proto3 | enum: 100} |> validate(allow_enum_integer: true)
    assert :ok = %Proto3{proto3 | enum: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 msg", %{proto3: %Proto3{msg: %Proto3.Msg{} = msg} = proto3} do
    import Proto3
    assert :ok = %Proto3{proto3 | msg: nil} |> validate
    assert {:error, _} = %Proto3{proto3 | msg: %URI{}} |> validate
    assert {:error, _} = %Proto3{proto3 | msg: %Proto3.Msg{msg | key: 123}} |> validate
    assert {:error, _} = %Proto3{proto3 | msg: %Proto3.Msg{msg | key: nil}} |> validate
    assert :ok = %Proto3{proto3 | msg: %Proto3.Msg{msg | key: nil}} |> validate(allow_scalar_nil: true)
  end

  test "proto3 oneof", %{proto3: %Proto3{either: {:either_msg, %Proto3.Msg{} = msg}} = proto3} do
    import Proto3
    assert :ok = %Proto3{proto3 | either: nil} |> validate
    assert :ok = %Proto3{proto3 | either: {:either_string, "hello"}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_string, 123}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_string, nil}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_string, nil}} |> validate(allow_scalar_nil: true)
    assert {:error, _} = %Proto3{proto3 | either: {:either_msg, 123}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_msg, nil}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:hello, "world"}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_msg, %Proto3.Msg{msg | key: 123}}} |> validate
  end

  #
  # TODO : proto2 tests
  #

end
