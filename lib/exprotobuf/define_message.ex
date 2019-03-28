defmodule Protobuf.DefineMessage do
  @moduledoc false

  alias Protobuf.Decoder
  alias Protobuf.Encoder
  alias Protobuf.Field
  alias Protobuf.OneOfField
  alias Protobuf.Delimited
  alias Protobuf.Utils
  require Protobuf.IntegerTypes, as: IntegerTypes
  require Protobuf.ValidatorOpts, as: ValidatorOpts

  def def_message(name, fields, [inject: inject, doc: doc, syntax: syntax]) when is_list(fields) do
    struct_fields = record_fields(fields)
    # Inject everything in 'using' module
    if inject do
      quote location: :keep do
        @root __MODULE__
        @record unquote(struct_fields)
        defstruct @record
        fields = unquote(struct_fields)

        def record, do: @record
        def syntax, do: unquote(syntax)

        unquote(define_typespec(name, fields))

        unquote(encode_decode(name))
        unquote(fields_methods(fields))
        unquote(oneof_fields_methods(fields))
        unquote(meta_information())
        unquote(constructors(name))
        unquote(validator(fields))

        defimpl Protobuf.Serializable do
          def serialize(object), do: unquote(name).encode(object)
        end
      end
    # Or create a nested module, with use_in functionality
    else
      quote location: :keep do
        root   = __MODULE__
        fields = unquote(struct_fields)
        use_in = @use_in[unquote(name)]

        defmodule unquote(name) do
          @moduledoc false
          unquote(Protobuf.Config.doc_quote(doc))
          @root root
          @record unquote(struct_fields)
          defstruct @record

          def record, do: @record
          def syntax, do: unquote(syntax)

          unquote(define_typespec(name, fields))

          unquote(encode_decode(name))
          unquote(fields_methods(fields))
          unquote(oneof_fields_methods(fields))
          unquote(meta_information())

          unquote(constructors(name))
          unquote(validator(fields))

          if use_in != nil do
            Module.eval_quoted(__MODULE__, use_in, [], __ENV__)
          end

          defimpl Protobuf.Serializable do
            def serialize(object), do: unquote(name).encode(object)
          end
        end

        unquote(define_oneof_modules(name, fields))
      end
    end
  end

  defp constructors(name) do
    quote location: :keep do
      def new(), do: new([])
      def new(values) do
        struct(unquote(name), values)
      end
    end
  end

  def define_typespec(module, field_list) when is_list(field_list) do
    case field_list do
      [%Field{name: :value, type: scalar, occurrence: occurrence}] when is_atom(scalar) ->
        scalar_wrapper? = Utils.is_standard_scalar_wrapper(module)
        cond do
          scalar_wrapper? and occurrence == :required ->
            quote do
              @type t() :: unquote(define_scalar_typespec(scalar))
            end

          scalar_wrapper? and occurrence == :optional ->
            quote do
              @type t() :: unquote(define_scalar_typespec(scalar)) | nil
            end

          not(scalar_wrapper?) ->
            define_trivial_typespec(module, field_list)
        end

      [%Field{name: :value, type: {:enum, enum_module}, occurrence: occurrence}] when is_atom(enum_module) ->
        enum_wrapper? = Utils.is_enum_wrapper(module, enum_module)
        cond do
          enum_wrapper? and occurrence == :required ->
            quote do
              @type t() :: unquote(enum_module).t()
            end

          enum_wrapper? and occurrence == :optional ->
            quote do
              @type t() :: unquote(enum_module).t() | nil
            end

          not(enum_wrapper?) ->
            define_trivial_typespec(module, field_list)
        end

      _ ->
        define_trivial_typespec(module, field_list)
    end
  end

  defp define_trivial_typespec(module, fields) when is_atom(module) and (module != nil) and is_list(fields) do
    field_types = define_trivial_typespec_fields(fields, [])
    default_type_ast = {
      :%,
      [],
      [
        {
          :__aliases__,
          [alias: false],
          module
          |> Module.split
          |> Enum.map(&String.to_atom/1)
        },
        {
          :%{},
          [],
          field_types
        }
      ]
    }
    type_ast =
      Protobuf.PostDecodable
      |> Module.concat(module)
      |> Code.ensure_loaded?
      |> case do
        true ->
          %{__struct__: module}
          |> Protobuf.PostDecodable.post_decoded_type
          |> case do
            nil -> default_type_ast
            ast -> ast
          end
        false ->
          default_type_ast
      end
    quote do
      @type t() :: unquote(type_ast)
    end
  end
  defp define_trivial_typespec_fields([], acc), do: Enum.reverse(acc)
  defp define_trivial_typespec_fields([%Protobuf.Field{ name: name, occurrence: :required, type: type } | rest], acc) do
    ast = {name, define_field_typespec(type)}
    define_trivial_typespec_fields(rest, [ast | acc])
  end
  defp define_trivial_typespec_fields([%Protobuf.Field{ name: name, occurrence: :optional, type: type } | rest], acc) do
    ast = {name, quote do unquote(define_field_typespec(type)) | nil end}
    define_trivial_typespec_fields(rest, [ast | acc])
   end
  defp define_trivial_typespec_fields([%Protobuf.Field{ name: name, occurrence: :repeated, type: type } | rest], acc) do
    ast = {name, quote do [unquote(define_field_typespec(type))] end}
    define_trivial_typespec_fields(rest, [ast | acc])
   end
  defp define_trivial_typespec_fields([%Protobuf.OneOfField{ name: name, fields: fields } | rest], acc) do
    ast = {name, quote do unquote(define_algebraic_type(fields)) end}
    define_trivial_typespec_fields(rest, [ast | acc])
   end
  defp define_algebraic_type(fields) do
    ast =
      for %Protobuf.Field{name: name, type: type} <- fields do
        {name, define_field_typespec(type)}
      end
    Protobuf.Utils.define_algebraic_type([nil | ast])
  end

  defp define_oneof_modules(namespace, fields) when is_list(fields) do
    ast =
      for %Protobuf.OneOfField{} = field <- fields do
        define_oneof_instance_module(namespace, field)
      end
    quote do
      unquote_splicing(ast)
    end
  end

  defp define_oneof_instance_module(namespace, %Protobuf.OneOfField{name: field, fields: fields}) do
    module_subname =
      field
      |> Atom.to_string()
      |> Macro.camelize()
      |> String.to_atom()

    fields = Enum.map(fields, &define_oneof_instance_macro/1)
    quote do
      defmodule unquote(Module.concat([namespace, :OneOf, module_subname])) do
        unquote_splicing(fields)
      end
    end
  end

  defp define_oneof_instance_macro(%Protobuf.Field{name: name}) do
    quote do
      defmacro unquote(name)(ast) do
        inner_name = unquote(name)
        quote do
          {unquote(inner_name), unquote(ast)}
        end
      end
    end
  end

  defp define_field_typespec(type) do
    case type do
      {:msg, field_module} ->
        quote do
          unquote(field_module).t()
        end
      {:enum, field_module} ->
        quote do
          unquote(field_module).t()
        end
      {:map, key_type, value_type} ->
        key_type_ast = define_field_typespec(key_type)
        value_type_ast = define_field_typespec(value_type)
        quote do
          [{unquote(key_type_ast), unquote(value_type_ast)}]
        end
      _ ->
        define_scalar_typespec(type)
    end
  end

  defp define_scalar_typespec(type) do
    case type do
      :double ->  quote do float() end
      :float -> quote do float() end
      :int32 -> quote do integer() end
      :int64 -> quote do integer() end
      :uint32 -> quote do non_neg_integer() end
      :uint64 -> quote do non_neg_integer() end
      :sint32 -> quote do integer() end
      :sint64 -> quote do integer() end
      :fixed32 -> quote do non_neg_integer() end
      :fixed64 -> quote do non_neg_integer() end
      :sfixed32 -> quote do integer() end
      :sfixed64 -> quote do integer() end
      :bool -> quote do boolean() end
      :string -> quote do String.t() end
      :bytes -> quote do binary() end
    end
  end

  defp encode_decode(_name) do
    quote do
      def decode(data),         do: Decoder.decode(data, __MODULE__)
      def encode(%{} = record), do: Encoder.encode(record, defs())
      def decode_delimited(bytes),    do: Delimited.decode(bytes, __MODULE__)
      def encode_delimited(messages), do: Delimited.encode(messages)
    end
  end

  defp fields_methods(fields) do
    for %Field{name: name, fnum: fnum} = field <- fields do
      quote location: :keep do
        def defs(:field, unquote(fnum)), do: unquote(Macro.escape(field))
        def defs(:field, unquote(name)), do: defs(:field, unquote(fnum))
      end
    end
  end

  defp oneof_fields_methods(fields) do
    for %OneOfField{name: name, rnum: rnum} = field <- fields do
      quote location: :keep do
        def defs(:field, unquote(rnum - 1)), do: unquote(Macro.escape(field))
        def defs(:field, unquote(name)), do: defs(:field, unquote(rnum - 1))
      end
    end
  end

  defp meta_information do
    quote do
      def defs,                   do: @root.defs
      def defs(:field, _),        do: nil
      def defs(:field, field, _), do: defs(:field, field)
      defoverridable [defs: 0]
    end
  end

  defp validator(fields) when is_list(fields) do
    expected_amount_of_fields = length(fields)
    quote do
      require Protobuf.IntegerTypes, as: IntegerTypes
      require Protobuf.Utils, as: Utils
      require Protobuf.ValidatorOpts, as: ValidatorOpts

      defmacro validate!(data, opts_data \\ []) do
        quote do
          unquote(data)
          |> unquote(__MODULE__).validate(unquote(opts_data))
          |> case do
            :ok -> :ok
            {:error, error} when is_binary(error) -> raise(error)
          end
        end
      end
      defmacro validate(data, opts_data \\ []) do
        opts = {
          :%,
          [],
          [
            {:__aliases__, [alias: false], [:Protobuf, :ValidatorOpts]},
            {:%{}, [], opts_data}
          ]
        }
        quote do
          unquote(data)
          |> unquote(__MODULE__).do_validate(%ValidatorOpts{unquote(opts) | msg_defs: Utils.msg_defs(unquote(__MODULE__).defs)})
        end
      end

      def do_validate(%__MODULE__{} = data, %ValidatorOpts{} = opts) do
        %{} = data_map = Map.from_struct(data)
        expected_amount_of_fields = unquote(expected_amount_of_fields)
        data_map
        |> map_size
        |> case do
          ^expected_amount_of_fields ->
            unquote(fields |> Macro.escape)
            |> Enum.reduce_while(:ok, fn
              %Field{name: name} = field, :ok ->
                data_map
                |> Map.fetch(name)
                |> case do
                  {:ok, val} ->
                    validate_field(val, field, opts)
                  :error ->
                    {:halt, {:error, "#{__MODULE__}.t should have field #{inspect name}"}}
                end
              %OneOfField{name: name} = oneof_field, :ok ->
                data_map
                |> Map.fetch(name)
                |> case do
                  {:ok, val} ->
                    validate_oneof_field(val, oneof_field, opts)
                  :error ->
                    {:halt, {:error, "#{__MODULE__}.t should have field #{inspect name}"}}
                end
            end)
          amount_of_fields ->
            {:error, "#{__MODULE__}.t should have #{expected_amount_of_fields} fields, but it has #{amount_of_fields} fields"}
        end
      end
      def do_validate(data, %ValidatorOpts{}) do
        {:error, "#{__MODULE__}.t was expected but got #{inspect data}"}
      end

      defp validate_field(val, %Field{type: {:map, _, _}} = field, %ValidatorOpts{} = opts) do
        validate_map_field(val, field, opts)
      end
      defp validate_field(val, %Field{occurrence: occurrence} = field, %ValidatorOpts{} = opts) do
        occurrence
        |> case do
          :repeated when is_list(val) ->
            fixed_field = %Field{field | occurrence: :required}
            val
            |> Enum.reduce_while(:ok, fn v, :ok ->
              validate_non_repeated_field(v, fixed_field, opts)
            end)
            |> case do
              :ok -> {:cont, :ok}
              {:error, _} = res -> {:halt, res}
            end
          :repeated ->
            invalid_value(val, field)
          :optional ->
            validate_non_repeated_field(val, field, opts)
          :required ->
            validate_non_repeated_field(val, field, opts)
        end
      end

      defp validate_non_repeated_field(val, %Field{occurrence: occurrence, type: type} = field, %ValidatorOpts{} = opts) do
        fixed_opts =
          opts
          |> case do
            %ValidatorOpts{allow_scalar_nil: true} when (occurrence == :required) ->
              %ValidatorOpts{opts | allow_scalar_nil: false}
            %ValidatorOpts{} when occurrence in [:optional, :required] ->
              opts
          end

        type
        |> case do
          :double -> validate_scalar_field(val, field, fixed_opts)
          :float -> validate_scalar_field(val, field, fixed_opts)
          :int32 -> validate_scalar_field(val, field, fixed_opts)
          :int64 -> validate_scalar_field(val, field, fixed_opts)
          :uint32 -> validate_scalar_field(val, field, fixed_opts)
          :uint64 -> validate_scalar_field(val, field, fixed_opts)
          :sint32 -> validate_scalar_field(val, field, fixed_opts)
          :sint64 -> validate_scalar_field(val, field, fixed_opts)
          :fixed32 -> validate_scalar_field(val, field, fixed_opts)
          :fixed64 -> validate_scalar_field(val, field, fixed_opts)
          :sfixed32 -> validate_scalar_field(val, field, fixed_opts)
          :sfixed64 -> validate_scalar_field(val, field, fixed_opts)
          :bool -> validate_scalar_field(val, field, fixed_opts)
          :string -> validate_scalar_field(val, field, fixed_opts)
          :bytes -> validate_scalar_field(val, field, fixed_opts)
          {:enum, _} -> validate_enum_field(val, field, fixed_opts)
          {:msg, _} -> validate_message_field(val, field, opts)
        end
      end

      defp validate_scalar_field(nil, %Field{} = field, %ValidatorOpts{allow_scalar_nil: true}) do
        {:cont, :ok}
      end
      defp validate_scalar_field(nil, %Field{} = field, %ValidatorOpts{allow_scalar_nil: false}) do
        {:halt, {:error, "#{__MODULE__}.t has nil value of field #{inspect field} where nil is not allowed"}}
      end
      defp validate_scalar_field(val, %Field{type: type} = field, %ValidatorOpts{}) do
        type
        |> case do
          :double when is_float(val) -> {:cont, :ok}
          :double -> invalid_value(val, field)

          :float when is_float(val) -> {:cont, :ok}
          :float -> invalid_value(val, field)

          :int32 when IntegerTypes.is_int32(val) -> {:cont, :ok}
          :int32 -> invalid_value(val, field)

          :int64 when IntegerTypes.is_int64(val) -> {:cont, :ok}
          :int64 -> invalid_value(val, field)

          :uint32 when IntegerTypes.is_uint32(val) -> {:cont, :ok}
          :uint32 -> invalid_value(val, field)

          :uint64 when IntegerTypes.is_uint64(val) -> {:cont, :ok}
          :uint64 -> invalid_value(val, field)

          :sint32 when IntegerTypes.is_int32(val) -> {:cont, :ok}
          :sint32 -> invalid_value(val, field)

          :sint64 when IntegerTypes.is_int64(val) -> {:cont, :ok}
          :sint64 -> invalid_value(val, field)

          :fixed32 when IntegerTypes.is_uint32(val) -> {:cont, :ok}
          :fixed32 -> invalid_value(val, field)

          :fixed64 when IntegerTypes.is_uint64(val) -> {:cont, :ok}
          :fixed64 -> invalid_value(val, field)

          :sfixed32 when IntegerTypes.is_int32(val) -> {:cont, :ok}
          :sfixed32 -> invalid_value(val, field)

          :sfixed64 when IntegerTypes.is_int64(val) -> {:cont, :ok}
          :sfixed64 -> invalid_value(val, field)

          :bool when is_boolean(val) -> {:cont, :ok}
          :bool -> invalid_value(val, field)

          :string ->
            val
            |> String.valid?
            |> case do
              true -> {:cont, :ok}
              false -> invalid_value(val, field)
            end

          :bytes when is_binary(val) -> {:cont, :ok}
          :bytes -> invalid_value(val, field)
        end
      end

      defp validate_enum_field(nil, %Field{} = field, %ValidatorOpts{allow_scalar_nil: true}) do
        {:cont, :ok}
      end
      defp validate_enum_field(nil, %Field{} = field, %ValidatorOpts{allow_scalar_nil: false}) do
        {:halt, {:error, "#{__MODULE__}.t has nil value of field #{inspect field} where nil is not allowed"}}
      end
      defp validate_enum_field(val, %Field{} = field, %ValidatorOpts{allow_enum_integer: true}) when IntegerTypes.is_int32(val) do
        {:cont, :ok}
      end
      defp validate_enum_field(val, %Field{} = field, %ValidatorOpts{allow_enum_integer: false}) when IntegerTypes.is_int32(val) do
        {:halt, {:error, "#{__MODULE__}.t has #{val} value of enum field #{inspect field} where int32 is not allowed"}}
      end
      defp validate_enum_field(val, %Field{type: {:enum, enum_module}} = field, %ValidatorOpts{}) do
        enum_module.atoms
        |> Enum.member?(val)
        |> case do
          true -> {:cont, :ok}
          false -> invalid_value(val, field)
        end
      end

      defp validate_message_field(nil, %Field{occurrence: :required} = field, %ValidatorOpts{}) do
        {:halt, {:error, "#{__MODULE__}.t has nil value of field #{inspect field} where nil is not allowed"}}
      end
      defp validate_message_field(nil, %Field{occurrence: :optional} = field, %ValidatorOpts{}) do
        {:cont, :ok}
      end
      defp validate_message_field(val,
                                  %Field{type: {:msg, msg_module}} = field,
                                  %ValidatorOpts{msg_defs: %{} = msg_defs} = opts) when Utils.is_scalar(val) do
        val
        |> Protobuf.Encoder.wrap_scalars_walker(field, msg_defs)
        |> case do
          ^val ->
            invalid_value(val, field)
          %_{value: ^val} = wrapped_val when map_size(wrapped_val) == 2 ->
            validate_message_field(wrapped_val, field, opts)
        end
      end
      defp validate_message_field(val, %Field{type: {:msg, msg_module}}, %ValidatorOpts{} = opts) do
        val
        |> Protobuf.PreEncodable.pre_encode(msg_module)
        |> msg_module.do_validate(opts)
        |> case do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end

      defp validate_map_field(%_{} = val, %Field{} = field, %ValidatorOpts{}) do
        invalid_value(val, field)
      end
      defp validate_map_field(%{} = val, %Field{} = field, %ValidatorOpts{} = opts) do
        val
        |> Enum.to_list
        |> validate_map_field(field, opts)
      end
      defp validate_map_field([_ | _] = val, %Field{type: {:map, tk, tv}} = field, opts) do
        field_key = %Protobuf.Field{
          fnum: 1,
          name: :key,
          occurrence: :required,
          opts: [],
          rnum: 1,
          type: tk
        }

        field_value = %Protobuf.Field{
          fnum: 1,
          name: :value,
          occurrence: :required,
          opts: [],
          rnum: 1,
          type: tv
        }

        val
        |> Enum.reduce_while(:ok, fn
          {k, v}, :ok ->
            validate_field(k, field_key, opts)
            |> case do
              {:cont, :ok} -> validate_field(v, field_value, opts)
              {:halt, {:error, _}} = error -> error
            end
          some, :ok ->
            {:halt, {:error, "invalid map element #{inspect some}"}}
        end)
        |> case do
          :ok -> {:cont, :ok}
          {:error, _} -> invalid_value(val, field)
        end
      end
      defp validate_map_field(val, %Field{} = field, %ValidatorOpts{}) do
        invalid_value(val, field)
      end

      defp validate_oneof_field(nil, %OneOfField{}, %ValidatorOpts{}) do
        {:cont, :ok}
      end
      defp validate_oneof_field({_, nil} = val, %OneOfField{} = oneof_field, %ValidatorOpts{}) do
        invalid_value(val, oneof_field)
      end
      defp validate_oneof_field({field_name, field_val} = val, %OneOfField{fields: fields} = oneof_field, %ValidatorOpts{} = opts) do
        fields
        |> Enum.filter(fn %Field{name: x} -> x == field_name end)
        |> case do
          [] -> invalid_value(val, oneof_field)
          [%Field{} = field] -> validate_non_repeated_field(field_val, field, opts)
        end
      end
      defp validate_oneof_field(val, %OneOfField{} = oneof_field, %ValidatorOpts{}) do
        invalid_value(val, oneof_field)
      end

      defp invalid_value(val, %Field{} = field) do
        {:halt, {:error, "#{__MODULE__}.t has invalid value #{inspect val} of field #{inspect field}"}}
      end
      defp invalid_value(val, %OneOfField{} = field) do
        {:halt, {:error, "#{__MODULE__}.t has invalid value #{inspect val} of field #{inspect field}"}}
      end
    end
  end

  defp record_fields(fields) do
    fields
    |> Enum.map(fn(field) ->
      case field do
        %Field{name: name, occurrence: :repeated} ->
          {name, []}
        %Field{name: name, opts: [default: default]} ->
          {name, default}
        %Field{name: name} ->
          {name, nil}
        %OneOfField{name: name} ->
          {name, nil}
        _ ->
          nil
      end
    end)
    |> Enum.reject(fn(field) -> is_nil(field) end)
  end
end
