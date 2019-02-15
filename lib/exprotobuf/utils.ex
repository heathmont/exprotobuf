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

  @type msg_defs :: %{module => MsgDef.t()}
  @type walker :: (term, Field.t() | OneOfField.t() | nil, msg_defs, module | nil -> term)

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

  @spec msg_defs(list) :: msg_defs
  def msg_defs(defs) when is_list(defs) do
    defs
    |> Enum.reduce(%{}, fn
      {{:msg, module}, meta}, %{} = acc ->
        Map.put(acc, module, do_msg_def(meta))

      {{type, _}, _}, acc = %{} when type in [:enum, :extensions, :service, :group] ->
        acc
    end)
  end

  @spec do_msg_def([]) :: MsgDef.t()
  defp do_msg_def(defs) when is_list(defs) do
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

  @doc """
  Performs traversal of given Elixir protobuf structure,
  applies given `Protobuf.Utils.walker` function to every node
  """
  @spec walk(term(), walker) :: term
  def walk(%msg_module{} = msg, walker) when is_function(walker, 4) do
    walk(msg, walker, msg_defs(msg_module.defs), nil)
  end

  @doc """
  Performs traversal of given Elixir term,
  applies given `Protobuf.Utils.walker` function to nodes
  according given `Protobuf.Utils.msg_defs` schema
  """
  @spec walk(term(), walker, msg_defs, module | nil) :: term
  def walk(%msg_module{} = msg, walker, %{} = msg_defs, original_msg_module)
      when is_function(walker, 4) and
             (msg_module == original_msg_module or is_nil(original_msg_module)) do
    msg
    |> Map.from_struct()
    |> Enum.reduce(msg, fn
      {key, {oneof, val}}, %_{} = acc when is_atom(oneof) ->
        {original_field_module, field_def} = fetch_field_def(msg_defs, msg_module, key, oneof)

        new_val =
          val
          |> case do
            %_{} ->
              walk(val, walker, msg_defs, original_field_module)

            %{} ->
              val
              |> Enum.map(fn
                {k, v} ->
                  {
                    walk(k, walker, msg_defs, original_field_module),
                    walk(v, walker, msg_defs, original_field_module)
                  }
              end)

            _ when is_scalar(val) or is_nil(val) ->
              walk(val, walker, msg_defs, original_field_module)
          end

        Map.put(
          acc,
          key,
          {
            oneof,
            walker.(
              new_val,
              field_def,
              msg_defs,
              original_field_module
            )
          }
        )

      {key, val}, %_{} = acc ->
        {original_field_module, field_def} = fetch_field_def(msg_defs, msg_module, key)

        new_val =
          val
          |> case do
            %_{} ->
              walk(val, walker, msg_defs, original_field_module)

            _ when is_list(val) or is_map(val) ->
              val
              |> Enum.map(fn
                {k, v} ->
                  {
                    walk(k, walker, msg_defs, original_field_module),
                    walk(v, walker, msg_defs, original_field_module)
                  }

                v ->
                  walk(v, walker, msg_defs, original_field_module)
              end)

            _ when is_scalar(val) or is_nil(val) ->
              walk(val, walker, msg_defs, original_field_module)
          end

        Map.put(
          acc,
          key,
          walker.(
            new_val,
            field_def,
            msg_defs,
            original_field_module
          )
        )
    end)
    |> walker.(nil, msg_defs, original_msg_module)
  end

  def walk(%_{} = val, walker, %{} = msg_defs, original_field_module)
      when is_function(walker, 4) and is_atom(original_field_module) do
    val
    |> walker.(nil, msg_defs, original_field_module)
    |> case do
      %msg_module{} = new_val when msg_module == original_field_module ->
        new_val
        |> walk(walker, msg_defs, original_field_module)

      new_val ->
        new_val
    end
  end

  def walk(val, walker, %{}, original_field_module)
      when is_function(walker, 4) and is_atom(original_field_module) do
    val
  end

  @spec fetch_field_def(msg_defs, module, atom) :: {nil | module, Field.t() | OneOfField.t()}
  defp fetch_field_def(%{} = msg_defs, msg_module, key)
       when is_atom(msg_module) and is_atom(key) do
    msg_defs
    |> case do
      %{
        ^msg_module => %MsgDef{
          fields: %{
            ^key => %Field{type: field_type} = field_def
          }
        }
      } ->
        field_type
        |> case do
          {:msg, original_msg_module} when is_atom(original_msg_module) ->
            {original_msg_module, field_def}

          _ ->
            {nil, field_def}
        end

      %{
        ^msg_module => %MsgDef{
          oneof_fields: %{
            ^key => %OneOfField{} = oneof_field_def
          }
        }
      } ->
        {nil, oneof_field_def}
    end
  end

  @spec fetch_field_def(msg_defs, module, atom, atom) :: {nil | module, Field.t()}
  defp fetch_field_def(%{} = msg_defs, msg_module, key, oneof)
       when is_atom(msg_module) and is_atom(key) and is_atom(oneof) do
    %{
      ^msg_module => %MsgDef{
        oneof_fields: %{
          ^key => %OneOfField{
            fields: %{
              ^oneof => %Field{type: field_type} = field_def
            }
          }
        }
      }
    } = msg_defs

    field_type
    |> case do
      {:msg, original_msg_module} when is_atom(original_msg_module) ->
        {original_msg_module, field_def}

      _ ->
        {nil, field_def}
    end
  end
end
