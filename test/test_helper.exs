Code.require_file("./utils/gpb_compile_helper.exs", __DIR__)
ExUnit.start()
Application.start(:stream_data)

defmodule Protobuf.Case do
  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: true
      alias GpbCompileHelper, as: Gpb
    end
  end
end
