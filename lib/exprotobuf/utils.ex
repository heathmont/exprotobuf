defmodule Protobuf.Utils do
  @moduledoc false
  alias Protobuf.Field
  alias Protobuf.MsgDef
  alias Protobuf.OneOfField

  @standard_scalar_wrappers %{
    "Google.Protobuf.DoubleValue" => true,
    "Google.Protobuf.FloatValue" => true,
    "Google.Protobuf.Int64Value" => true,
    "Google.Protobuf.UInt64Value" => true,
    "Google.Protobuf.Int32Value" => true,
    "Google.Protobuf.UInt32Value" => true,
    "Google.Protobuf.BoolValue" => true,
    "Google.Protobuf.StringValue" => true,
    "Google.Protobuf.BytesValue" => true
  }

  defmacro is_scalar(v) do
    quote do
      (is_atom(unquote(v)) and unquote(v) != nil) or
        is_number(unquote(v)) or
        is_binary(unquote(v))
    end
  end

  def is_standard_scalar_wrapper(module) when is_atom(module) do
    mod =
      module
      |> Module.split()
      |> Stream.take(-3)
      |> Enum.join(".")

    Map.has_key?(@standard_scalar_wrappers, mod)
  end

  def is_enum_wrapper(module, enum_module) when is_atom(module) and is_atom(enum_module) do
    Atom.to_string(module) == "#{enum_module}Value"
  end

  def define_algebraic_type([item]), do: item

  def define_algebraic_type([lhs, rhs]) do
    quote do
      unquote(lhs) | unquote(rhs)
    end
  end

  def define_algebraic_type([lhs | rest]) do
    quote do
      unquote(lhs) | unquote(define_algebraic_type(rest))
    end
  end

  def convert_to_record(map, module) do
    module.record
    |> Enum.reduce([record_name(module)], fn {key, default}, acc ->
      value = Map.get(map, key, default)
      [value_transform(module, value) | acc]
    end)
    |> Enum.reverse()
    |> List.to_tuple()
  end

  def msg_defs(defs) when is_list(defs) do
    defs
    |> Enum.reduce(%{}, fn
      {{:msg, module}, meta}, %{} = acc ->
        Map.put(acc, module, do_msg_defs(meta))

      {{type, _}, _}, acc = %{} when type in [:enum, :extensions, :service, :group] ->
        acc
    end)
  end

  defp do_msg_defs(defs) when is_list(defs) do
    defs
    |> Enum.reduce(%MsgDef{}, fn
      %Field{name: field_name} = field_meta, %MsgDef{fields: %{} = acc_fields} = acc ->
        %MsgDef{acc | fields: Map.put(acc_fields, field_name, field_meta)}

      %OneOfField{name: oneof_name, fields: fields} = oneof_meta,
      %MsgDef{oneof_fields: %{} = acc_oneof_fields} = acc ->
        fields_map =
          fields
          |> Enum.reduce(%{}, fn %Field{name: field_name} = field_meta, %{} = acc_fields ->
            Map.put(acc_fields, field_name, field_meta)
          end)

        new_oneof_meta = %OneOfField{oneof_meta | fields: fields_map}
        %MsgDef{acc | oneof_fields: Map.put(acc_oneof_fields, oneof_name, new_oneof_meta)}
    end)
  end

  defp record_name(OneOfField), do: :gpb_oneof
  defp record_name(Field), do: :field
  defp record_name(type), do: type

  defp value_transform(_module, nil), do: :undefined

  defp value_transform(OneOfField, value) when is_list(value) do
    Enum.map(value, &convert_to_record(&1, Field))
  end

  defp value_transform(_module, value), do: value

  def convert_from_record(rec, module) do
    map = struct(module)

    module.record
    |> Enum.with_index()
    |> Enum.reduce(map, fn {{key, _default}, idx}, acc ->
      # rec has the extra element when defines the record type
      value = elem(rec, idx + 1)
      Map.put(acc, key, value)
    end)
  end

  #
  # walker = fn(value, %_{} = field_def, %{} = msg_defs) -> ... end
  #
  # field_def :: %Field{} | %OneOfField{} | nil
  #
  def walk(%msg_module{} = msg, walker) when is_function(walker, 3) do
    walk(msg, walker, msg_defs(msg_module.defs))
  end

  def walk(%msg_module{} = msg, walker, %{} = msg_defs)
      when is_function(walker, 3) do
    msg
    |> Map.from_struct()
    |> Enum.reduce(msg, fn
      {key, {oneof, val}}, %_{} = acc when is_atom(oneof) ->
        new_val =
          val
          |> case do
            %_{} -> walk(val, walker, msg_defs)
            _ when is_scalar(val) or is_nil(val) -> walk(val, walker, msg_defs)
          end

        Map.put(
          acc,
          key,
          {
            oneof,
            walker.(
              new_val,
              fetch_field_def(msg_defs, msg_module, key, oneof),
              msg_defs
            )
          }
        )

      {key, val}, %_{} = acc ->
        new_val =
          val
          |> case do
            %_{} ->
              walk(val, walker, msg_defs)

            _ when is_list(val) or is_map(val) ->
              val
              |> Enum.map(fn
                {k, v} ->
                  {
                    walk(k, walker, msg_defs),
                    walk(v, walker, msg_defs)
                  }

                v ->
                  walk(v, walker, msg_defs)
              end)

            _ when is_scalar(val) or is_nil(val) ->
              walk(val, walker, msg_defs)
          end

        Map.put(
          acc,
          key,
          walker.(
            new_val,
            fetch_field_def(msg_defs, msg_module, key),
            msg_defs
          )
        )
    end)
    |> walker.(nil, msg_defs)
  end

  def walk(val, walker, %{}) when is_function(walker, 3), do: val

  defp fetch_field_def(%{} = msg_defs, msg_module, key)
       when is_atom(msg_module) and is_atom(key) do
    msg_defs
    |> case do
      %{
        ^msg_module => %MsgDef{
          fields: %{
            ^key => %Field{} = field_def
          }
        }
      } ->
        field_def

      %{
        ^msg_module => %MsgDef{
          oneof_fields: %{
            ^key => %OneOfField{} = oneof_field_def
          }
        }
      } ->
        oneof_field_def
    end
  end

  defp fetch_field_def(%{} = msg_defs, msg_module, key, oneof)
       when is_atom(msg_module) and is_atom(key) and is_atom(oneof) do
    %{
      ^msg_module => %MsgDef{
        oneof_fields: %{
          ^key => %OneOfField{
            fields: %{
              ^oneof => %Field{} = field_def
            }
          }
        }
      }
    } = msg_defs

    field_def
  end
end
